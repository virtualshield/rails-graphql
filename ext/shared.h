#include "ruby.h"
#include "gql_parser.h"

#if !defined RB_INT_PARSE_DEFAULT
#define RB_INT_PARSE_DEFAULT 0x07
#endif

#define GQL_PUTS(...) gql_debug_print(RSTRING_PTR(rb_sprintf(__VA_ARGS__)))

#define GQL_I_STRUCTURE_FST 0x10
#define GQL_I_STRUCTURE_LST 0x1f

#define GQL_I_VALUE_FST 0x20
#define GQL_I_VALUE_LST 0x2f

#define GQL_I_EXECUTION_FST 0x30
#define GQL_I_EXECUTION_LST 0x3f

#define GQL_I_OPERATIONS_FST 0x30
#define GQL_I_OPERATIONS_LST 0x32

#define GQL_I_DEFINITION_FST 0x40
#define GQL_I_DEFINITION_LST 0x4f

#define GQL_I_STRUCTURE(x) (x >= GQL_I_STRUCTURE_FST && x <= GQL_I_STRUCTURE_LST)
#define GQL_I_VALUE(x) (x >= GQL_I_VALUE_FST && x <= GQL_I_VALUE_LST)
#define GQL_I_EXECUTION(x) (x >= GQL_I_EXECUTION_FST && x <= GQL_I_EXECUTION_LST)
#define QGL_I_OPERATION(x) (x >= GQL_I_OPERATIONS_FST && x <= GQL_I_OPERATIONS_LST)
#define GQL_I_DEFINITION(x) (x >= GQL_I_DEFINITION_FST && x <= GQL_I_DEFINITION_LST)

// https://www.asciitable.com/
#define GQL_S_IGNORE(x) (x == ' ' || x == ',' || x == '\n' || x == '\r' || x == '\t' || x == '\f' || x == '\b')
#define GQL_S_CHARACTER(x) ((x >= 'a' && x <= 'z') || (x >= 'A' && x <= 'Z') || x == '_')
#define GQL_S_DIGIT(x) (x >= '0' && x <= '9')
#define GQL_S_FLOAT_MARK(x) (x == '.' || x == 'e' || x == 'E')

#define GQL_SCAN_ERROR(scanner) (scanner->lexeme == gql_i_eof || scanner->lexeme == gql_i_unknown)
#define GQL_SCAN_SIZE(scanner) (scanner->current_pos - scanner->start_pos)
#define GQL_SCAN_CHAR(scanner) (scanner->doc[scanner->current_pos])
#define GQL_SCAN_LOOK(scanner, bytes) (scanner->doc[scanner->current_pos + bytes])
#define GQL_SCAN_NEXT(scanner) ({            \
  scanner->current_pos++;                    \
  scanner->current = GQL_SCAN_CHAR(scanner); \
})
#define GQL_SCAN_NEW_LINE(scanner) ({         \
  scanner->last_ln_at = scanner->current_pos; \
  scanner->current_line++;                    \
})
#define GQL_SCAN_WHILE(scanner, check) ({ \
  while (check)                           \
  {                                       \
    if (GQL_SCAN_CHAR(scanner) == '\n')   \
    {                                     \
      GQL_SCAN_NEW_LINE(scanner);         \
    }                                     \
    GQL_SCAN_NEXT(scanner);               \
  }                                       \
})
#define GQL_SCAN_SET_END(scanner, offset) ({                                 \
  scanner->end_line = scanner->begin_line;                                   \
  scanner->end_column = scanner->current_pos - offset - scanner->last_ln_at; \
})
#define GQL_SCAN_SAVE(scanner, memory) ({ \
  memory[0] = scanner->begin_line;        \
  memory[1] = scanner->begin_column;      \
})

#define GQL_SAFE_PUSH(source, value) ({ \
  if (NIL_P(source))                    \
    source = rb_ary_new();              \
  rb_ary_push(source, value);           \
})

enum gql_lexeme
{
  // Basic identifiers
  gql_i_eof              = 0x00,
  gql_i_name             = 0x01,
  gql_i_comment          = 0x02,
  gql_i_variable         = 0x03,
  gql_i_directive        = 0x04,

  // Structure identifiers
  gql_is_op_curly        = 0x10,
  gql_is_cl_curly        = 0x11,
  gql_is_op_paren        = 0x12,
  gql_is_cl_paren        = 0x13,
  gql_is_op_brack        = 0x14,
  gql_is_cl_brack        = 0x15,
  gql_is_colon           = 0x16,
  gql_is_equal           = 0x17,
  gql_is_period          = 0x18,

  // Value based types
  gql_iv_integer         = 0x20,
  gql_iv_float           = 0x21,
  gql_iv_string          = 0x22,
  gql_iv_true            = 0x23,
  gql_iv_false           = 0x24,
  gql_iv_null            = 0x25,
  gql_iv_enum            = 0x26,
  gql_iv_array           = 0x27,
  gql_iv_hash            = 0x28,
  gql_iv_heredoc         = 0x2f,

  // Execution keywords
  gql_ie_query           = 0x30,
  gql_ie_mutation        = 0x31,
  gql_ie_subscription    = 0x32,
  gql_ie_fragment        = 0x33,
  gql_ie_on              = 0x34,

  // Definition keywords
  gql_id_schema          = 0x40,
  gql_id_directive       = 0x41,
  gql_id_enum            = 0x42,
  gql_id_input           = 0x43,
  gql_id_interface       = 0x44,
  gql_id_scalar          = 0x45,
  gql_id_type            = 0x46,
  gql_id_union           = 0x47,
  gql_id_extend          = 0x48,
  gql_id_implements      = 0x49,
  gql_id_repeatable      = 0x4a,

  // Something went wrong
  gql_i_unknown          = 0xff
};

struct gql_scanner
{
  unsigned long start_pos;
  unsigned long current_pos;
  unsigned long current_line;
  unsigned long last_ln_at;
  unsigned long begin_line;
  unsigned long begin_column;
  unsigned long end_line;
  unsigned long end_column;
  char *doc;
  char current;
  enum gql_lexeme lexeme;
};

extern const char *GQL_VALUE_KEYWORDS[3];
extern const char *GQL_EXECUTION_KEYWORDS[5];
extern const char *GQL_DEFINITION_KEYWORDS[12];

void gql_debug_print(const char *message);
struct gql_scanner gql_new_scanner(VALUE source);

enum gql_lexeme gql_upgrade_basis(const char *upgrade_from[]);
enum gql_lexeme gql_name_to_keyword(struct gql_scanner *scanner, const char *upgrade_from[]);

enum gql_lexeme gql_read_name(struct gql_scanner *scanner);
enum gql_lexeme gql_read_comment(struct gql_scanner *scanner);
enum gql_lexeme gql_read_hash(struct gql_scanner *scanner);
enum gql_lexeme gql_read_float(struct gql_scanner *scanner);
enum gql_lexeme gql_read_number(struct gql_scanner *scanner);
enum gql_lexeme gql_read_string(struct gql_scanner *scanner, int allow_heredoc);

void gql_next_lexeme(struct gql_scanner *scanner);
void gql_next_lexeme_no_comments(struct gql_scanner *scanner);

VALUE gql_set_token_type(VALUE self, const char *type);
VALUE gql_inspect_token(VALUE self);
VALUE gql_token_of_type_check(VALUE self, VALUE other);
VALUE gql_as_token(VALUE self, struct gql_scanner *scanner, int save_type);

VALUE gql_scanner_to_s(struct gql_scanner *scanner);
VALUE gql_scanner_to_token(struct gql_scanner *scanner);
VALUE gql_array_to_rb(struct gql_scanner *scanner);
VALUE gql_value_to_rb(struct gql_scanner *scanner, int accept_var);
VALUE gql_value_to_token(struct gql_scanner *scanner, int accept_var);
