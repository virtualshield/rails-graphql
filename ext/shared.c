#include "ruby.h"
#include "shared.h"

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
  char *doc = RSTRING_PTR(source);
  struct gql_scanner scanner = {
      .start_pos = 1, // Set to 1 just to begin different from the current position
      .current_pos = 0,
      .current_line = 1,
      .last_ln_at = 0,
      .current = doc[0],
      .doc = doc};

  return scanner;
}

// Returns the base index of the lexeme from where the upgrade should move from
enum gql_lexeme gql_upgrade_basis(const char *upgrade_from[])
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
enum gql_lexeme gql_name_to_keyword(struct gql_scanner *scanner, const char *keywords[], unsigned int size)
{
  unsigned long pos, len = GQL_SCAN_SIZE(scanner);
  unsigned int valid = 0;
  const char *keyword;

  // Check until it finds the end of the array
  for (size_t i = 0; i < size; ++i)
  {
    // Move ot the next item and check the current for different size
    keyword = keywords[i];
    if(strlen(keyword) == len)
    {
      // We cannot use the normal strcomp because we are comparing a mid part of the string
      for (pos = 0, valid = 1; valid == 1 && pos < len; pos++)
      {
        if (keyword[pos] != scanner->doc[scanner->start_pos + pos])
          valid = 0;
      }

      // Only return if valid was kept as true
      if (valid == 1) return gql_upgrade_basis(keywords) + i;
    }
  }

  // Return name if was not able to upgrade to a keyword
  return gql_i_name;
}

/* SCANNER HELPERS */
enum gql_lexeme gql_read_name(struct gql_scanner *scanner)
{
  // Read all the chars and digits
  GQL_SCAN_WHILE(scanner, GQL_S_CHARACTER(scanner->current) || GQL_S_DIGIT(scanner->current));
  return gql_i_name;
}

enum gql_lexeme gql_read_comment(struct gql_scanner *scanner)
{
  // Move forward until it finds a new line, change the line indicator and return
  GQL_SCAN_WHILE(scanner, scanner->current != '\n');
  GQL_SCAN_NEW_LINE(scanner);
  return gql_i_comment;
}

enum gql_lexeme gql_read_hash(struct gql_scanner *scanner)
{
  // Start with 1 curly open and get the next
  int curly_opens = 1;
  GQL_SCAN_NEXT(scanner);

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
    else if (scanner->current == '\n')
      GQL_SCAN_NEW_LINE(scanner);

    // Just move to the next char
    GQL_SCAN_NEXT(scanner);
  }

  // Save the last position, move to the next and return as hash
  return gql_iv_hash;
}

enum gql_lexeme gql_read_float(struct gql_scanner *scanner)
{
  // If what made it get in here was an '.', then it can recurse to the exponent of a fraction
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
  GQL_SCAN_WHILE(scanner, GQL_S_DIGIT(scanner->current));

  // If it is at fraction and the next is an exponent marker, then recurse
  if (at_fraction && (scanner->current == 'e' || scanner->current == 'E'))
    return gql_read_float(scanner);

  // Otherwise save the last position and just finish the float
  return gql_iv_float;
}

enum gql_lexeme gql_read_number(struct gql_scanner *scanner)
{
  // Pass over the negative sign
  if (scanner->current == '-') GQL_SCAN_NEXT(scanner);

  // If begins with zero, it can only be 0 or error
  if (scanner->current == '0')
    return (GQL_S_DIGIT(GQL_SCAN_LOOK(scanner, 1))) ? gql_i_unknown : gql_iv_integer;

  // Read all the numbers
  GQL_SCAN_WHILE(scanner, GQL_S_DIGIT(scanner->current));

  // Save the last position and halt the process if it's not a float marker
  return (GQL_S_FLOAT_MARK(scanner->current)) ? gql_read_float(scanner) : gql_iv_integer;
}

enum gql_lexeme gql_read_string(struct gql_scanner *scanner, int allow_heredoc)
{
  int start_size, end_size = 0;
  unsigned long start = scanner->current_pos;

  // Read all the initial quotes and save the size
  GQL_SCAN_WHILE(scanner, scanner->current == '"');
  start_size = (int)(scanner->current_pos - start);

  // 4, 5, or more than 6 means an invalid triple-quotes block
  if (start_size == 4 || start_size == 5 || start_size > 6)
    return gql_i_unknown;

  // 3 but not accepting heredoc returns an unknown
  if (allow_heredoc == 0 && start_size == 3)
    return gql_i_unknown;

  // 2 or 6 means empty string
  if (start_size == 2 || start_size == 6)
    return gql_iv_string;

  // Read until the start and end number of quotes matches
  while (start_size != end_size)
  {
    // If it is a quote, add to end and move ot the next
    if (scanner->current == '"')
    {
      end_size++;
    }
    else
    {
      // Anything that is not a quote reset the end size
      end_size = 0;

      // If we get to the end of the file, return an unknown
      if (scanner->current == '\0')
        return gql_i_unknown;

      // Make sure to mark any new lines
      if (scanner->current == '\n')
        GQL_SCAN_NEW_LINE(scanner);

      // Skip one extra character, which means it is skipping the escaped char
      if (scanner->current == '\\')
        GQL_SCAN_NEXT(scanner);
    }

    // Move the cursor
    GQL_SCAN_NEXT(scanner);
  }

  // Regardless if a quote comes next, this is now a valid string
  return (start_size == 3) ? gql_iv_heredoc : gql_iv_string;
}

/* MOST IMPORTANT TOKEN READ FUNCTION */
void gql_next_lexeme(struct gql_scanner *scanner)
{
  // Do not move forward if it is unknown
  if (scanner->lexeme == gql_i_unknown)
    return;

  // Temporary save the end line and end column
  GQL_SCAN_SET_END(scanner, 0);

  // Skip everything that can be ignored
  GQL_SCAN_WHILE(scanner, GQL_S_IGNORE(scanner->current));

  // Mark where the new interesting thing has started
  scanner->start_pos = scanner->current_pos;
  scanner->begin_line = scanner->current_line;
  scanner->begin_column = scanner->current_pos - scanner->last_ln_at;

  // Find what might be the next interesting thing
  if (scanner->current == '\0')
    scanner->lexeme = gql_i_eof;
  else if (GQL_S_CHARACTER(scanner->current))
    scanner->lexeme = gql_read_name(scanner);
  else if (scanner->current == '#')
    scanner->lexeme = gql_read_comment(scanner);
  else if (GQL_S_DIGIT(scanner->current) || scanner->current == '-')
    scanner->lexeme = gql_read_number(scanner);
  else if (scanner->current == '"')
    scanner->lexeme = gql_read_string(scanner, 1);
  else if (scanner->current == '[')
    scanner->lexeme = gql_is_op_brack;
  else if (scanner->current == '{')
    scanner->lexeme = gql_is_op_curly;
  else if (scanner->current == '}')
    scanner->lexeme = gql_is_cl_curly;
  else if (scanner->current == '(')
    scanner->lexeme = gql_is_op_paren;
  else if (scanner->current == ')')
    scanner->lexeme = gql_is_cl_paren;
  else if (scanner->current == ':')
    scanner->lexeme = gql_is_colon;
  else if (scanner->current == '=')
    scanner->lexeme = gql_is_equal;
  else if (scanner->current == '.')
    scanner->lexeme = gql_is_period;
  else if (scanner->current == '@')
    scanner->lexeme = gql_i_directive;
  else if (scanner->current == '$')
    scanner->lexeme = gql_i_variable;
  else
    scanner->lexeme = gql_i_unknown;
}

// Skip all comment lexemes
void gql_next_lexeme_no_comments(struct gql_scanner *scanner)
{
  do
  {
    gql_next_lexeme(scanner);
  } while (scanner->lexeme == gql_i_comment);
}

/* TOKEN CLASS HELPERS AND METHODS */
// Simply add the type of the token and return self for simplicity
VALUE gql_set_token_type(VALUE self, const char *type)
{
  rb_iv_set(self, "@type", ID2SYM(rb_intern(type)));
  return self;
}

// Just simply format the string with the token prefix
VALUE gql_inspect_token(VALUE self)
{
  VALUE text = rb_call_super(0, 0);

  if (rb_ivar_defined(self, rb_intern("@type")) == Qfalse)
    return rb_sprintf("<GQLParser::Token %" PRIsVALUE ">", text);

  VALUE type = rb_iv_get(self, "@type");
  return rb_sprintf("<GQLParser::Token [%" PRIsVALUE "] %" PRIsVALUE ">", type, text);
}

// Check if the token is of the given type
VALUE gql_token_of_type_check(VALUE self, VALUE other)
{
  VALUE type = rb_iv_get(self, "@type");
  return rb_equal(type, other);
}

// Add the token module to the object and assign its location information
VALUE gql_as_token(VALUE self, struct gql_scanner *scanner, int save_type)
{
  // Initialize the instance
  VALUE instance = rb_class_new_instance(1, &self, QLGParserToken);

  // Add the location instance variables
  int offset = scanner->begin_line == 1 ? 1 : 0;
  rb_iv_set(instance, "@begin_line", ULONG2NUM(scanner->begin_line));
  rb_iv_set(instance, "@begin_column", ULONG2NUM(scanner->begin_column + offset));

  offset = scanner->end_line == 1 ? 1 : 0;
  rb_iv_set(instance, "@end_line", ULONG2NUM(scanner->end_line));
  rb_iv_set(instance, "@end_column", ULONG2NUM(scanner->end_column + offset));

  // Check if it has to save the type
  if (save_type == 1)
  {
    // This only covers value types
    if (scanner->lexeme == gql_iv_integer)
      gql_set_token_type(instance, "int");
    else if (scanner->lexeme == gql_iv_float)
      gql_set_token_type(instance, "float");
    else if (scanner->lexeme == gql_iv_string)
      gql_set_token_type(instance, "string");
    else if (scanner->lexeme == gql_iv_true)
      gql_set_token_type(instance, "boolean");
    else if (scanner->lexeme == gql_iv_false)
      gql_set_token_type(instance, "boolean");
    else if (scanner->lexeme == gql_iv_enum)
      gql_set_token_type(instance, "enum");
    else if (scanner->lexeme == gql_iv_array)
      gql_set_token_type(instance, "array");
    else if (scanner->lexeme == gql_iv_hash)
      gql_set_token_type(instance, "hash");
    else if (scanner->lexeme == gql_iv_heredoc)
      gql_set_token_type(instance, "heredoc");
  }

  // Return the token instance
  return instance;
}

/* RUBY-BASED HELPERS */
// Creates a Ruby String from the scanner
VALUE gql_scanner_to_s(struct gql_scanner *scanner)
{
  return rb_str_new(scanner->doc + scanner->start_pos, GQL_SCAN_SIZE(scanner));
}

// Same as the above, but already extend it to a parser token
VALUE gql_scanner_to_token(struct gql_scanner *scanner)
{
  return gql_as_token(gql_scanner_to_s(scanner), scanner, 0);
}

// Goes over an array and grab all the elements
VALUE gql_array_to_rb(struct gql_scanner *scanner)
{
  // Start the array and the temporary element
  VALUE result = rb_ary_new();
  VALUE element;

  // Save the scan and grab the next char
  GQL_SCAN_NEXT(scanner);

  // Iterate until it finds the end of the array
  while (scanner->current != ']')
  {
    // If we got to the end of the file and the array was not closed, then we have something wrong
    if (scanner->current == '\0')
    {
      scanner->lexeme = gql_i_unknown;
      return Qnil;
    }

    // Save the element as an rb token, because we may need the type of each element afterwards
    element = gql_value_to_token(scanner, 0);

    // If it found an unknown, then we bubble the problem up
    if (scanner->lexeme == gql_i_unknown)
      return Qnil;

    // Add the value to the array and scan through everything ignorable
    rb_ary_push(result, element);
    GQL_SCAN_WHILE(scanner, GQL_S_IGNORE(scanner->current));
  }

  // Save where the array has actually ended, change the lexeme and return
  GQL_SCAN_SET_END(scanner, 0);
  scanner->lexeme = gql_iv_array;
  return result;
}

// Turn the current lexeme into its proper ruby object
VALUE gql_value_to_rb(struct gql_scanner *scanner, int accept_var)
{
  // EXPERIMENTAL! Skip all the comments
  gql_next_lexeme_no_comments(scanner);

  // If got a variable and accepts variables,
  // then it's fine and it won't be resolved in here
  if (accept_var == 1 && scanner->lexeme == gql_i_variable)
    return Qnil;

  // Make sure to save the end position of the value
  GQL_SCAN_SET_END(scanner, 0);

  // If it's a name, then it can be a keyword or a enum value
  if (scanner->lexeme == gql_i_name)
  {
    scanner->lexeme = GQL_SAFE_NAME_TO_KEYWORD(scanner, GQL_VALUE_KEYWORDS);
    if (scanner->lexeme == gql_iv_true)
      return Qtrue;
    else if (scanner->lexeme == gql_iv_false)
      return Qfalse;
    else if (scanner->lexeme == gql_iv_null)
      return Qnil;
    else
      scanner->lexeme = gql_iv_enum;
  }

  // Dealing with an array is way more complex, because you have to turn each
  // individual value as an rb value
  if (scanner->lexeme == gql_is_op_brack)
    return gql_array_to_rb(scanner);

  // If it is a hash, then we can just read through it and later get as a string
  if (scanner->lexeme == gql_is_op_curly)
    scanner->lexeme = gql_read_hash(scanner);

  // By getting here with a proper value, just return the string of it, which
  // will be dealt in the request
  if (GQL_I_VALUE(scanner->lexeme))
    return gql_scanner_to_s(scanner);

  // If it got to this point, then it's an unknown
  scanner->lexeme = gql_i_unknown;
  return Qnil;
}

// Same as the above, but already extend it to a parser token
// IMPORTANT! This might generate a problem because nil, true, and false won't
// become parser tokens
VALUE gql_value_to_token(struct gql_scanner *scanner, int accept_var)
{
  return gql_as_token(gql_value_to_rb(scanner, accept_var), scanner, 1);
}
