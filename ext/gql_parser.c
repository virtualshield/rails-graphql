#include <string.h>
#include <math.h>

#include "ruby.h"
#include "shared.h"
#include "gql_parser.h"

// EXECUTION DOCUMENT [OPERATION*, FRAGMENT*]
VALUE gql_parse_execution(VALUE self, VALUE document);

// OPERATION [type?, name?, VARIABLE*, DIRECTIVE*, FIELD*]
VALUE gql_parse_operation(struct gql_scanner *scanner);

// FRAGMENT [name, type, DIRECTIVE*, FIELD*]
VALUE gql_parse_fragment(struct gql_scanner *scanner);

// VARIABLE [name, TYPE, value?, DIRECTIVE*]*
VALUE gql_parse_variables(struct gql_scanner *scanner);

// VARIABLE [name, TYPE, value?, DIRECTIVE*]
VALUE gql_parse_variable(struct gql_scanner *scanner);

// DIRECTIVE [name, ARGUMENT*]*
VALUE gql_parse_directives(struct gql_scanner *scanner);

// DIRECTIVE [name, ARGUMENT*]
VALUE gql_parse_directive(struct gql_scanner *scanner);

// FIELD [name, alias?, ARGUMENT*, DIRECTIVE*, FIELD*]*
VALUE gql_parse_fields(struct gql_scanner *scanner);

// FIELD [name, alias?, ARGUMENT*, DIRECTIVE*, FIELD*]
VALUE gql_parse_field(struct gql_scanner *scanner);

// ARGUMENT [name, value?, var_name?]*
VALUE gql_parse_arguments(struct gql_scanner *scanner);

// ARGUMENT [name, value?, var_name?]
VALUE gql_parse_argument(struct gql_scanner *scanner);

// SPREAD [name?, type?, DIRECTIVE*, FIELD*]
VALUE gql_parse_spread(struct gql_scanner *scanner);

// TYPE [name, dimensions?, nullability]
VALUE gql_parse_type(struct gql_scanner *scanner);

// Little helper to simplify returning problems
VALUE gql_nil_and_unknown(struct gql_scanner *scanner);

// Little helper to assign the start memoized position
VALUE gql_token_start_from_mem(VALUE instance, unsigned long memory[2]);

// Central error method
NORETURN(void gql_throw_parser_error(struct gql_scanner *scanner));

/* STRUCTURES
 *
 * EXECUTION DOCUMENT [OPERATION*, FRAGMENT*]
 * OPERATION [type?, name?, VARIABLE*, DIRECTIVE*, FIELD*]
 * FRAGMENT [name, type, DIRECTIVE*, FIELD*]
 *
 * VARIABLE [name, TYPE, value?, DIRECTIVE*]
 * DIRECTIVE [name, ARGUMENT*]
 * FIELD [alias?, name, ARGUMENT*, DIRECTIVE*, FIELD*]
 * ARGUMENT [name, value?, var_name?]
 */

/* ALL THE PARSERS METHODS FOR THE ABOVE STRUCTURES */
// Parse an execution document
// EXECUTION DOCUMENT [OPERATION*, FRAGMENT*]
VALUE gql_parse_execution(VALUE self, VALUE document)
{
  if (!RB_TYPE_P(document, T_STRING))
    rb_raise(rb_eArgError, "%+" PRIsVALUE " is not a string", document);

  // Initialize its pieces
  VALUE pieces[] = {Qnil, Qnil};
  struct gql_scanner scanner = gql_new_scanner(document);
  gql_next_lexeme_no_comments(&scanner);

  // Go over all the operations and fragments
  while (scanner.lexeme != gql_i_eof)
  {
    // Try to upgrade if the token is a name
    if (scanner.lexeme == gql_i_name)
      scanner.lexeme = GQL_SAFE_NAME_TO_KEYWORD(&scanner, GQL_EXECUTION_KEYWORDS);

    // It can contain either operations or fragments, anything else is unknown and an error
    if (QGL_I_OPERATION(scanner.lexeme) || scanner.lexeme == gql_is_op_curly)
      GQL_SAFE_PUSH(pieces[0], gql_parse_operation(&scanner));
    else if (scanner.lexeme == gql_ie_fragment)
      GQL_SAFE_PUSH(pieces[1], gql_parse_fragment(&scanner));
    else if (scanner.lexeme != gql_i_comment)
      scanner.lexeme = gql_i_unknown;

    // If anything made the scanner fall into an unknown, throw an error
    if (scanner.lexeme == gql_i_unknown)
      gql_throw_parser_error(&scanner);
  }

  // Return the plain array, no need to turn into a token
  return rb_ary_new4(2, pieces);
}

// Parse an operation element
// OPERATION [type?, name?, VARIABLE*, DIRECTIVE*, FIELD*]
VALUE gql_parse_operation(struct gql_scanner *scanner)
{
  // Common header
  unsigned long mem[2];
  GQL_SCAN_SAVE(scanner, mem);
  VALUE pieces[] = {Qnil, Qnil, Qnil, Qnil, Qnil};

  // Save the type
  const char *type = "query";

  // When we have the operation type, we may have all the other stuff as well
  if (QGL_I_OPERATION(scanner->lexeme))
  {
    // Save the operation type
    type = RSTRING_PTR(gql_scanner_to_s(scanner));
    GQL_ASSIGN_TOKEN_AND_NEXT(pieces[0], scanner);

    // Save the name of the operation
    if (scanner->lexeme == gql_i_name)
      GQL_ASSIGN_TOKEN_AND_NEXT(pieces[1], scanner);

    // Save the variables of the operation
    if (scanner->lexeme == gql_is_op_paren)
      GQL_ASSIGN_VALUE_AND_NEXT(pieces[2], scanner, gql_parse_variables(scanner));

    // Save the directives of the operation
    if (scanner->lexeme == gql_i_directive)
      GQL_ASSIGN_VALUE_AND_NEXT(pieces[3], scanner, gql_parse_directives(scanner));
  }

  // Collect all the fields for this operation, or return nil for non-typed operation with empty body
  // With empty body operation, make sure to move to the next token
  if (scanner->lexeme == gql_is_op_curly)
    GQL_ASSIGN_VALUE_AND_NEXT(pieces[4], scanner, gql_parse_fields(scanner));
  else if (NIL_P(pieces[0]))
    return gql_nil_and_unknown(scanner);

  // Generate the result array with proper scan location and return
  return GQL_BUILD_PARSE_OUTER_TOKEN(type, 5, pieces, scanner, mem);
}

// FRAGMENT [name, type, DIRECTIVE*, FIELD*]
VALUE gql_parse_fragment(struct gql_scanner *scanner)
{
  // Common header
  unsigned long mem[2];
  GQL_SCAN_SAVE(scanner, mem);
  VALUE pieces[] = {Qnil, Qnil, Qnil, Qnil};

  // Make sure we have a name and it is not "on"
  gql_next_lexeme_no_comments(scanner);
  if (scanner->lexeme != gql_i_name)
    return gql_nil_and_unknown(scanner);
  else if (GQL_SAFE_NAME_TO_KEYWORD(scanner, GQL_EXECUTION_KEYWORDS) == gql_ie_on)
    return gql_nil_and_unknown(scanner);

  // Save the name of the fragment
  GQL_ASSIGN_TOKEN_AND_NEXT(pieces[0], scanner);

  // If we don't have an "on" next, we have a problem
  if (GQL_SAFE_NAME_TO_KEYWORD(scanner, GQL_EXECUTION_KEYWORDS) != gql_ie_on)
    return gql_nil_and_unknown(scanner);

  // Skip the on and ensure that next is a name
  gql_next_lexeme_no_comments(scanner);
  if (scanner->lexeme != gql_i_name)
    return gql_nil_and_unknown(scanner);

  // Save the name of the type
  GQL_ASSIGN_TOKEN_AND_NEXT(pieces[1], scanner);

  // Save the directives of the fragment
  if (scanner->lexeme == gql_i_directive)
    GQL_ASSIGN_VALUE_AND_NEXT(pieces[2], scanner, gql_parse_directives(scanner));

  // Normally fields would be mandatory, but the gem will accept empty body fragments
  if (scanner->lexeme == gql_is_op_curly)
    GQL_ASSIGN_VALUE_AND_NEXT(pieces[3], scanner, gql_parse_fields(scanner));

  // Generate the result array with proper scan location and return
  return GQL_BUILD_PARSE_OUTER_TOKEN("fragment", 4, pieces, scanner, mem);
}

// VARIABLE [name, TYPE, value?, DIRECTIVE*]*
VALUE gql_parse_variables(struct gql_scanner *scanner)
{
  // The list can be nil if "()"
  VALUE result = Qnil;

  // Skip the (
  GQL_SCAN_NEXT(scanner);
  gql_next_lexeme_no_comments(scanner);

  // Look for the end of the parenthesis
  while (scanner->lexeme != gql_is_cl_paren)
  {
    if (GQL_SCAN_ERROR(scanner))
      return gql_nil_and_unknown(scanner);

    GQL_SAFE_PUSH(result, gql_parse_variable(scanner));
  }

  // Just return the array filled with variables, no need to make it as a token
  GQL_SCAN_NEXT(scanner);
  return result;
}

// VARIABLE [name, TYPE, value?, DIRECTIVE*]
VALUE gql_parse_variable(struct gql_scanner *scanner)
{
  // Common header
  unsigned long mem[2];
  GQL_SCAN_SAVE(scanner, mem);
  VALUE pieces[] = {Qnil, Qnil, Qnil, Qnil};

  // Make sure that it starts with an "$" sign
  if (scanner->lexeme != gql_i_variable)
    return gql_nil_and_unknown(scanner);

  // Skip the $
  GQL_SCAN_NEXT(scanner);
  scanner->start_pos++;

  // If we don't have a name indicator, we return an error
  if (!GQL_S_CHARACTER(scanner->current))
    return gql_nil_and_unknown(scanner);

  // Read and save the name
  scanner->lexeme = gql_read_name(scanner);
  GQL_ASSIGN_TOKEN_AND_NEXT(pieces[0], scanner);

  // Next is the colon before the type
  if (scanner->lexeme != gql_is_colon)
    return gql_nil_and_unknown(scanner);

  // Skip the :
  GQL_SCAN_NEXT(scanner);

  // Now check for the type, which can be a brack for array or just the type
  gql_next_lexeme_no_comments(scanner);
  if (scanner->lexeme != gql_is_op_brack && scanner->lexeme != gql_i_name)
    return gql_nil_and_unknown(scanner);

  // Save the type of the variable
  GQL_ASSIGN_VALUE_AND_NEXT(pieces[1], scanner, gql_parse_type(scanner));

  // If the next lexeme is an equal sign, then we have to capture the value
  if (scanner->lexeme == gql_is_equal)
  {
    GQL_SCAN_NEXT(scanner);
    GQL_ASSIGN_VALUE_AND_NEXT(pieces[2], scanner, gql_value_to_token(scanner, 0));
  }

  // Save the directives of the variable
  if (scanner->lexeme == gql_i_directive)
    GQL_ASSIGN_VALUE_AND_NEXT(pieces[3], scanner, gql_parse_directives(scanner));

  // Generate the result array with proper scan location and return
  return GQL_BUILD_PARSE_OUTER_TOKEN("variable", 4, pieces, scanner, mem);
}

// DIRECTIVE [name, ARGUMENT*]*
VALUE gql_parse_directives(struct gql_scanner *scanner)
{
  // Start the list of directives, we have at least one when it gets here
  VALUE result = rb_ary_new();

  // Look for all the directives
  while (scanner->lexeme == gql_i_directive)
    rb_ary_push(result, gql_parse_directive(scanner));

  // Just return the array filled with variables, no need to make it as a token
  return result;
}

// DIRECTIVE [name, ARGUMENT*]
VALUE gql_parse_directive(struct gql_scanner *scanner)
{
  // Common header
  unsigned long mem[2];
  GQL_SCAN_SAVE(scanner, mem);
  VALUE pieces[] = {Qnil, Qnil};

  // Skip the @
  GQL_SCAN_NEXT(scanner);
  scanner->start_pos++;

  // If we don't have a name indicator, we return an error
  if (!GQL_S_CHARACTER(scanner->current))
    return gql_nil_and_unknown(scanner);

  // Read and save the name
  scanner->lexeme = gql_read_name(scanner);
  GQL_ASSIGN_TOKEN_AND_NEXT(pieces[0], scanner);

  // Save the arguments of the directive
  if (scanner->lexeme == gql_is_op_paren)
    GQL_ASSIGN_VALUE_AND_NEXT(pieces[1], scanner, gql_parse_arguments(scanner));

  // Generate the result array with proper scan location and return
  return GQL_BUILD_PARSE_OUTER_TOKEN("directive", 2, pieces, scanner, mem);
}

// FIELD [alias?, name, ARGUMENT*, DIRECTIVE*, FIELD*]*
VALUE gql_parse_fields(struct gql_scanner *scanner)
{
  // The list can be nil if "{}"
  VALUE result = Qnil;

  // Skip the {
  GQL_SCAN_NEXT(scanner);
  gql_next_lexeme_no_comments(scanner);

  // Look for the end of the curly
  while (scanner->lexeme != gql_is_cl_curly)
  {
    if (GQL_SCAN_ERROR(scanner))
      return gql_nil_and_unknown(scanner);
    else if (scanner->lexeme == gql_is_period)
      GQL_SAFE_PUSH(result, gql_parse_spread(scanner));
    else
      GQL_SAFE_PUSH(result, gql_parse_field(scanner));
  }

  // Just return the array filled with fields, no need to make it as a token
  GQL_SCAN_NEXT(scanner);
  return result;
}

// FIELD [name, alias?, ARGUMENT*, DIRECTIVE*, FIELD*]
VALUE gql_parse_field(struct gql_scanner *scanner)
{
  // Common header
  unsigned long mem[2];
  GQL_SCAN_SAVE(scanner, mem);
  VALUE pieces[] = {Qnil, Qnil, Qnil, Qnil, Qnil};

  // If we don't have a name, we have a problem
  if (scanner->lexeme != gql_i_name)
    return gql_nil_and_unknown(scanner);

  GQL_ASSIGN_TOKEN_AND_NEXT(pieces[0], scanner);

  // If we got a colon, then we actually had an alias and not the name
  if (scanner->lexeme == gql_is_colon)
  {
    // Move one further and get the next lexeme
    GQL_SCAN_NEXT(scanner);
    gql_next_lexeme_no_comments(scanner);

    // If we don't have a name after, we have a problem
    if (scanner->lexeme != gql_i_name)
      return gql_nil_and_unknown(scanner);

    // Save the alias and the actual field name
    pieces[1] = pieces[0];
    GQL_ASSIGN_TOKEN_AND_NEXT(pieces[0], scanner);
  }

  // Save the arguments of the field
  if (scanner->lexeme == gql_is_op_paren)
    GQL_ASSIGN_VALUE_AND_NEXT(pieces[2], scanner, gql_parse_arguments(scanner));

  // Save the directives of the field
  if (scanner->lexeme == gql_i_directive)
    GQL_ASSIGN_VALUE_AND_NEXT(pieces[3], scanner, gql_parse_directives(scanner));

  // Save the fields of the field
  if (scanner->lexeme == gql_is_op_curly)
  {
    GQL_ASSIGN_VALUE_AND_NEXT(pieces[4], scanner, gql_parse_fields(scanner));

    // If fields were initiated but came back empty, we have a problem
    if (NIL_P(pieces[4]))
      return gql_nil_and_unknown(scanner);
  }

  // Generate the result array with proper scan location and return
  return GQL_BUILD_PARSE_OUTER_TOKEN("field", 5, pieces, scanner, mem);
}

// ARGUMENT [name, value?, var_name?]*
VALUE gql_parse_arguments(struct gql_scanner *scanner)
{
  // The list can be nil if "()"
  VALUE result = Qnil;

  // Skip the (
  GQL_SCAN_NEXT(scanner);
  gql_next_lexeme_no_comments(scanner);

  // Look for the end of the parenthesis
  while (scanner->lexeme != gql_is_cl_paren)
  {
    if (GQL_SCAN_ERROR(scanner))
      return gql_nil_and_unknown(scanner);

    GQL_SAFE_PUSH(result, gql_parse_argument(scanner));
  }

  // Just return the array filled with arguments, no need to make it as a token
  GQL_SCAN_NEXT(scanner);
  return result;
}

// ARGUMENT [name, value?, var_name?]
VALUE gql_parse_argument(struct gql_scanner *scanner)
{
  // Common header
  unsigned long mem[2];
  GQL_SCAN_SAVE(scanner, mem);
  VALUE pieces[] = {Qnil, Qnil, Qnil};

  // If we don't have a name after, we have a problem
  if (scanner->lexeme != gql_i_name)
    return gql_nil_and_unknown(scanner);

  GQL_ASSIGN_TOKEN_AND_NEXT(pieces[0], scanner);

  // If we don't have a colon after, we have a problem, because we need a value
  if (scanner->lexeme != gql_is_colon)
    return gql_nil_and_unknown(scanner);

  // Move one further and assume that the next lexeme will be a value
  GQL_SCAN_NEXT(scanner);
  pieces[1] = gql_value_to_rb(scanner, 1);

  // If we successfully got a value, not a var,
  // then just make it as a token and move to the next
  if (GQL_I_VALUE(scanner->lexeme))
  {
    pieces[1] = gql_as_token(pieces[1], scanner, 1);
    gql_next_lexeme_no_comments(scanner);
  }
  else if (scanner->lexeme == gql_i_variable)
  {
    // Skip the $ for a variable
    GQL_SCAN_NEXT(scanner);
    scanner->start_pos++;

    // If we don't have a name indicator, we return an error
    if (!GQL_S_CHARACTER(scanner->current))
      return gql_nil_and_unknown(scanner);

    // Read and save only the name
    scanner->lexeme = gql_read_name(scanner);
    pieces[2] = gql_set_token_type(gql_scanner_to_token(scanner), "variable");
    gql_next_lexeme_no_comments(scanner);
  }
  else
    return gql_nil_and_unknown(scanner);

  // Generate the result array with proper scan location and return
  return GQL_BUILD_PARSE_OUTER_TOKEN("argument", 3, pieces, scanner, mem);
}

// SPREAD [name?, type?, DIRECTIVE*, FIELD*]
VALUE gql_parse_spread(struct gql_scanner *scanner)
{
  // Common header
  unsigned long mem[2];
  GQL_SCAN_SAVE(scanner, mem);
  VALUE pieces[] = {Qnil, Qnil, Qnil, Qnil};

  // Make sure that we have 2 other periods and something else right after
  if (GQL_SCAN_LOOK(scanner, 1) != '.' || GQL_SCAN_LOOK(scanner, 2) != '.' || GQL_SCAN_LOOK(scanner, 3) == '.')
    return gql_nil_and_unknown(scanner);

  // Move after the periods and get the next lexeme
  scanner->current_pos += 3;
  scanner->current = GQL_SCAN_CHAR(scanner);
  gql_next_lexeme_no_comments(scanner);

  // According to the spec, the type condition or the name are optional
  if (scanner->lexeme == gql_i_name)
  {
    // Upgrade the name because it will decide if it is an inline spread or not
    scanner->lexeme = GQL_SAFE_NAME_TO_KEYWORD(scanner, GQL_EXECUTION_KEYWORDS);

    // If we are at "on" then we have an inline spread, otherwise a fragment referenced by name
    if (scanner->lexeme == gql_ie_on)
    {
      gql_next_lexeme_no_comments(scanner);

      // If we don't have a name after, we have a problem
      if (scanner->lexeme != gql_i_name)
        return gql_nil_and_unknown(scanner);

      // Save it as the type of the spread
      GQL_ASSIGN_TOKEN_AND_NEXT(pieces[1], scanner);
    }
    else
      GQL_ASSIGN_TOKEN_AND_NEXT(pieces[0], scanner);
  }

  // Save the directives of the field
  if (scanner->lexeme == gql_i_directive)
    GQL_ASSIGN_VALUE_AND_NEXT(pieces[2], scanner, gql_parse_directives(scanner));

  // Spread without a name needs fields
  if (NIL_P(pieces[0]))
  {
    // No curly means we have a problem
    if (scanner->lexeme != gql_is_op_curly)
      return gql_nil_and_unknown(scanner);

    // Save the fields
    GQL_ASSIGN_VALUE_AND_NEXT(pieces[3], scanner, gql_parse_fields(scanner));

    // If fields were initiated but came back empty, we have a problem
    if (NIL_P(pieces[3]))
      return gql_nil_and_unknown(scanner);
  }

  // Generate the result array with proper scan location and return
  return GQL_BUILD_PARSE_OUTER_TOKEN("spread", 4, pieces, scanner, mem);
}

// TYPE [name, dimensions, nullability]
VALUE gql_parse_type(struct gql_scanner *scanner)
{
  VALUE pieces[] = {Qnil, Qnil, Qnil};

  // Important info about the type
  unsigned int dimensions = 0;
  unsigned int nullability = 0;

  // Check for all the open brackets before the type
  while (scanner->current == '[' || (dimensions > 0 && GQL_S_IGNORE(scanner->current)))
  {
    if (scanner->current == '\0')
      return gql_nil_and_unknown(scanner);
    else if (scanner->current == '[')
      dimensions++;

    GQL_SCAN_NEXT(scanner);
  }

  // If any dimensions where identified, then get the next lexeme for the name
  if (dimensions > 0)
    gql_next_lexeme(scanner);

  // If it is not a name, then we have a problem, otherwise save the name
  if (scanner->lexeme != gql_i_name)
    return gql_nil_and_unknown(scanner);

  pieces[0] = gql_scanner_to_token(scanner);
  pieces[1] = UINT2NUM(dimensions);

  // Now go over all the close brackets, exclamations, and ignorables
  while (scanner->current == '!' || scanner->current == ']' || GQL_S_IGNORE(scanner->current))
  {
    if (scanner->current == '\0')
      return gql_nil_and_unknown(scanner);
    else if (scanner->current == '!')
      nullability += pow(2, dimensions);
    else if (scanner->current == ']')
      dimensions--;

    GQL_SCAN_NEXT(scanner);
  }

  // If there are dimensions still open, we have a problem
  if (dimensions > 0)
    return gql_nil_and_unknown(scanner);

  // Save the last position, last line, and the nullability
  GQL_SCAN_SET_END(scanner, 1);
  pieces[2] = UINT2NUM(nullability);

  // Return the valid parsed type
  return GQL_BUILD_PARSE_TOKEN("type", 3, pieces, scanner);
}

// Simply set the scanner as unkown and return nil, to simplify validation
VALUE gql_nil_and_unknown(struct gql_scanner *scanner)
{
  scanner->lexeme = gql_i_unknown;
  return Qnil;
}

// Little helper to assign the start memoized position
VALUE gql_token_start_from_mem(VALUE instance, unsigned long memory[2])
{
  int offset = memory[0] == 1 ? 1 : 0;
  rb_iv_set(instance, "@begin_line", ULONG2NUM(memory[0]));
  rb_iv_set(instance, "@begin_column", ULONG2NUM(memory[1] + offset));
  return instance;
}

// A centralized way to express that the parser was unsuccessful
void gql_throw_parser_error(struct gql_scanner *scanner)
{
  VALUE line = ULONG2NUM(scanner->begin_line);
  VALUE column = ULONG2NUM(scanner->begin_column);
  VALUE token;

  if (GQL_SCAN_SIZE(scanner) > 0)
    token = gql_scanner_to_s(scanner);
  else if (scanner->current != '\0')
    token = rb_str_new(&scanner->current, 1);
  else
    token = rb_str_new2("EOF");

  const char *message = "Parser error: unexpected \"%" PRIsVALUE "\" at [%" PRIsVALUE ", %" PRIsVALUE "]";
  rb_raise(gql_eParserError, message, token, line, column);
}

void Init_gql_parser()
{
  GQLParser = rb_define_module("GQLParser");
  rb_define_singleton_method(GQLParser, "parse_execution", gql_parse_execution, 1);
  rb_define_const(GQLParser, "VERSION", rb_str_new2("October 2021"));

  QLGParserToken = rb_define_class_under(GQLParser, "Token", rb_path2class("SimpleDelegator"));
  rb_define_method(QLGParserToken, "of_type?", gql_token_of_type_check, 1);
  rb_define_method(QLGParserToken, "inspect", gql_inspect_token, 0);
  rb_define_attr(QLGParserToken, "begin_line", 1, 0);
  rb_define_attr(QLGParserToken, "begin_column", 1, 0);
  rb_define_attr(QLGParserToken, "end_line", 1, 0);
  rb_define_attr(QLGParserToken, "end_column", 1, 0);
  rb_define_attr(QLGParserToken, "type", 1, 0);

  gql_eParserError = rb_define_class_under(GQLParser, "ParserError", rb_eStandardError);
}
