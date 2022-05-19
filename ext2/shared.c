#include "ruby.h"

#include "shared.h"

VALUE GQLParser = Qnil;
VALUE QLGParserToken = Qnil;
VALUE gql_eParserError = Qnil;

const char *GQL_VALUE_KEYWORDS[] = {
  "true",
  "false",
  "null"
};

const char *GQL_EXECUTION_KEYWORDS[] = {
  "query",
  "mutation",
  "subscription",
  "fragment",
  "on"
};

const char *GQL_DEFINITION_KEYWORDS[] = {
  "schema",
  "directive",
  "enum",
  "input",
  "interface",
  "scalar",
  "type",
  "union",
  "extend",
  "implements",
  "repeatable"
};

/* INTERNAL HELPERS */
// Just a helper to print things on the console while testing/debugging
void gql_debug_print(const char *message)
{
  rb_funcall(rb_mKernel, rb_intern("puts"), 1, rb_str_new2(message));
}

// Initialize a new scanner
struct gql_scanner gql_new_scanner(VALUE source)
{
  struct gql_scanner scanner = {0, 0, 1, 1, -1, RSTRING_PTR(source)};
  scanner.current = scanner.doc[0];
  return scanner;
}

// Get what is in the scanner right now and return as a C string
// It's IMPERATIVE to +ALLOCV_END(GQLParser)+ after the use
char *gql_scanner_to_char(struct gql_scanner *scanner)
{
  // ruby-2.7.5/object.c:3600
  long len = GQL_SCAN_SIZE(scanner);
  // char *segment = ALLOCV(GQLParser, len + 1);
  // MEMCPY(segment, (scanner->doc + scanner->start_pos), char, len);
  // segment[len] = '\0';

  char *segment = malloc(len + 1);

  memset(segment, '\0', len + 1);
  strncpy(segment, scanner->doc + scanner->start_pos, len);
  return segment;
}

// Returns the base index of the token from where the upgrade should move from
enum gql_identifier gql_upgrade_basis(const char *upgrade_from[])
{
  if (*upgrade_from == *GQL_VALUE_KEYWORDS)
    return gql_iv_true;
  else if (*upgrade_from == *GQL_EXECUTION_KEYWORDS)
    return gql_ie_query;
  else if (*upgrade_from == *GQL_DEFINITION_KEYWORDS)
    return gql_id_schema;
  else
    return gql_i_unknown;
}

// This checks if the identifier in the scanner should be upgraded to a keyword
enum gql_identifier gql_identifier_to_keyword(struct gql_scanner *scanner, const char *upgrade_from[])
{
  unsigned long pos, len = GQL_SCAN_SIZE(scanner);
  unsigned int valid = 0, i = 0;
  const char *keyword;

  // Check until it finds the end of the array
  while ((keyword = upgrade_from[i]) != 0)
  {
    // Move ot the next item and check the current for different size
    if(strlen(keyword) == len)
    {
      // We cannot use the normal strcomp because we are cimparing a mid part of the string
      for (pos = 0, valid = 1; valid == 1 && pos < len; pos++)
      {
        if (keyword[pos] != scanner->doc[scanner->start_pos + pos])
          valid = 0;
      }

      // Only return if valid was kept as true
      if (valid == 1) return gql_upgrade_basis(upgrade_from) + i;
    }

    // Move to the next index
    i++;
  }

  // Return name if was not able to upgrade to a keyword
  return gql_i_name;
}

/* SCANNER HELPERS */
enum gql_identifier gql_read_name(struct gql_scanner *scanner)
{
  // Read all the chars and digits
  GQL_READ_WHILE(scanner, GQL_S_CHARACTER(scanner->current) || GQL_S_DIGIT(scanner->current));
  return gql_i_name;
}

enum gql_identifier gql_read_comment(struct gql_scanner *scanner)
{
  // Move forward until it finds a new line
  GQL_READ_WHILE(scanner, scanner->current != '\n');
  return gql_i_comment;
}

enum gql_identifier gql_read_hash(struct gql_scanner *scanner)
{
  // Start with 1 curly open
  int curly_opens = 1;

  while (curly_opens > 0)
  {
    // EOF returns unknown, { adds to the open, } removes from the open, " reads as string
    if (scanner->current == '\0')
      return gql_i_unknown;
    else if (scanner->current == '"' && gql_read_string(scanner, 0) != gql_iv_string)
      return gql_i_unknown;
    else if (scanner->current == '{')
      curly_opens++;
    else if (scanner->current == '}')
      curly_opens--;

    // Just move to the next char
    GQL_SCAN_NEXT(scanner);
  }

  // Mark the result as an Hash
  return gql_iv_hash;
}

enum gql_identifier gql_read_float(struct gql_scanner *scanner)
{
  // If what made it get in here was an '.', then it can recurse to the expoenent of a fraction
  int at_fraction = scanner->current == '.';

  // Skip the float mark and maybe
  GQL_SCAN_NEXT(scanner);

  // Skip the exponent sign if possible
  if (!at_fraction && (scanner->current == '+' || scanner->current == '-'))
    GQL_SCAN_NEXT(scanner);

  // If the current char is not a digit, we have an unknown
  if (!GQL_S_DIGIT(scanner->current)) return gql_i_unknown;
  GQL_SCAN_NEXT(scanner);

  // Read all the numbers
  GQL_READ_WHILE(scanner, GQL_S_DIGIT(scanner->current));

  // If it is at fraction and the next is an exponent marker, then recurse
  if (at_fraction && (scanner->current == 'e' || scanner->current == 'E'))
    return gql_read_float(scanner);

  // Otherwise just finish the float
  return gql_iv_float;
}

enum gql_identifier gql_read_number(struct gql_scanner *scanner)
{
  // Pass over the negative sign
  if (scanner->current == '-') GQL_SCAN_NEXT(scanner);

  // If begins with zero, it can only be 0 or error
  if (scanner->current == '0')
    return (GQL_S_DIGIT(GQL_SCAN_LOOK(scanner, 1))) ? gql_i_unknown : gql_iv_int;

  // Read all the numbers
  GQL_READ_WHILE(scanner, GQL_S_DIGIT(scanner->current));

  // Halt the process if it's not a float marker
  return (GQL_S_FLOAT_MARK(scanner->current)) ? gql_read_float(scanner) : gql_iv_int;
}

enum gql_identifier gql_read_string(struct gql_scanner *scanner, int allow_heredoc)
{
  int start_size, end_size;

  // Read all the initial quotes and save the size
  GQL_READ_WHILE(scanner, scanner->current == '"');
  start_size = GQL_SCAN_SIZE(scanner);

  // 4, 5, or more than 6 means an invalid tripple-quotes block
  if (start_size == 4 || start_size == 5 || start_size > 6) return gql_i_unknown;

  // 3 but not accepting heredoc returns an unknown
  if (allow_heredoc == 0 && start_size == 3) return gql_i_unknown;

  // 2 or 6 means empty string
  if (start_size == 2 || start_size == 6) return gql_iv_string;

  // Read until the start and end number of quotes matches
  while (start_size != end_size)
  {
    // If it is a quote, add to end and move ot the next
    if (scanner->current == '"')
    {
      end_size++;
      continue;
    }

    // If we get to the end of the file, return an unknown
    if (scanner->current == '\0') return gql_i_unknown;

    // Skip one extra character, which means it is skipping the escapped char
    if (scanner->current == '\\') GQL_SCAN_NEXT(scanner);

    // Move the cursor and reset the end size
    GQL_SCAN_NEXT(scanner);
    end_size = 0;
  }

  // Regardless if a quote comes next, this is now a valid string
  return (start_size == 3) ? gql_iv_heredoc : gql_iv_string;
}

/* MOST IMPORTANT TOKEN READ FUNCTION */
void gql_next_token(struct gql_scanner *scanner)
{
  // Skip all the ignorables
  GQL_READ_WHILE(scanner, GQL_S_IGNORE(scanner->current));

  // Mark where something interesting has started
  scanner->start_pos = scanner->current_pos;
  scanner->start_line = scanner->current_line;

  // Find what might be the next interesting thing
  if (scanner->current == '\0')
    scanner->token = gql_i_eof;
  else if (GQL_S_CHARACTER(scanner->current))
    scanner->token = gql_read_name(scanner);
  else if (scanner->current == '#')
    scanner->token = gql_read_comment(scanner);
  else if (GQL_S_DIGIT(scanner->current) || scanner->current == '-')
    scanner->token = gql_read_number(scanner);
  else if (scanner->current == '"')
    scanner->token = gql_read_string(scanner, 1);
  else if (scanner->current == '{')
    scanner->token = gql_is_op_curly;
  else if (scanner->current == '(')
    scanner->token = gql_is_op_paren;
  else if (scanner->current == '[')
    scanner->token = gql_is_op_brack;
  else if (scanner->current == ':')
    scanner->token = gql_is_colon;
  else if (scanner->current == '@')
    scanner->token = gql_i_directive;
  else if (scanner->current == '$')
    scanner->token = gql_i_variable;
  else
    scanner->token = gql_i_unknown;
}

/* RUBY-BASED HELPERS */
// Just simply format the string with the token prefix
VALUE gql_inspect_token(VALUE self)
{
  return rb_sprintf("<GQLParser::Token %" PRIsVALUE ">", rb_call_super(0, 0));
}

// Add the token module to the object and assign its location information
VALUE gql_as_token(VALUE self, struct gql_scanner *scanner)
{
  VALUE instance = rb_class_new_instance(1, &self, QLGParserToken);
  rb_iv_set(instance, "@begin_line", ULONG2NUM(scanner->start_line));
  rb_iv_set(instance, "@begin_column", ULONG2NUM(scanner->start_pos - scanner->last_nl_at));
  rb_iv_set(instance, "@end_line", ULONG2NUM(scanner->current_line));
  rb_iv_set(instance, "@end_column", ULONG2NUM(scanner->current_pos - scanner->last_nl_at));
  // Save the token type as a symbol
  // Add a method to check the type of the token
  return instance;
}

// Creates a Ruby String from the scanner and mark it as a parser token
VALUE gql_scanner_to_s(struct gql_scanner *scanner)
{
  return rb_str_new(scanner->doc + scanner->start_pos, GQL_SCAN_SIZE(scanner));
}

// Same as the above, but already extend it to a parser token
VALUE gql_scanner_to_token(struct gql_scanner *scanner)
{
  return gql_as_token(gql_scanner_to_s(scanner), scanner);
}

// Turn the current token into its proper ruby object
VALUE gql_value_to_rb(struct gql_scanner *scanner)
{
  VALUE tmp;
  char *str;

  // EXPERIMENTAL! Skip all the possible comments
  do {
    gql_next_token(scanner);
  } while(scanner->token == gql_i_comment);

  // Perform necessary actions based on the current token
  switch (scanner->token)
  {
  case gql_i_name:
    // This can mean an enum value or true/false/null
    scanner->token = gql_identifier_to_keyword(scanner, GQL_VALUE_KEYWORDS);
    switch (scanner->token)
    {
      case gql_iv_true:
        return Qtrue;
      case gql_iv_false:
        return Qfalse;
      case gql_iv_null:
        return Qnil;
      case gql_i_name:
        scanner->token = gql_iv_enum;
        return gql_scanner_to_s(scanner);
    }
  case gql_iv_int:
    // TODO: Maybe just simply use substr and to proper to_i function
    // Turn this string into an integer, it's safe
    // ruby-2.7.5/bignum.c:4239
    return rb_int_parse_cstr(
        (scanner->doc + scanner->start_pos),
        (long)GQL_SCAN_SIZE(scanner),
        NULL, NULL, 10, RB_INT_PARSE_DEFAULT);
  case gql_iv_float:
    // TODO: Maybe just simply use substr and to proper to_f function
    // Turn this string into a float, it's safe
    // ruby-2.7.5/object.c:3574
    str = gql_scanner_to_char(scanner);
    tmp = DBL2NUM(rb_cstr_to_dbl(str, 0));
    free(str);
    return tmp;
  case gql_iv_string:
    return Qnil;
  default:
    scanner->token = gql_i_unknown;
    return Qnil;
  }
}

// Same as the above, but already extend it to a parser token
// IMPORTANT! This might generate a problem because nil, true, and false won't
// become parser tokens
VALUE gql_value_to_token(struct gql_scanner *scanner)
{
  return gql_as_token(gql_value_to_rb(scanner), scanner);
}
