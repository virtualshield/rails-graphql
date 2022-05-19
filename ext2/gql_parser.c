#include <string.h>

#include "ruby.h"
#include "extconf.h"
#include "shared.h"

// VALUE
// gql_parse_operation(const char *doc, struct gql_scanner *scanner, enum gql_identifier *token)
// {
//   // OPERATION [type?, name?, VARIABLE*, DIRECTIVE*, FIELD*]
//   VALUE pieces[] = {Qnil, Qnil, Qnil, Qnil};

//   if (QGL_I_OPERATION(*token))
//   {
//     pieces[0] = gql_extract_from_doc(doc, scanner);
//     *token = gql_next_token(doc, scanner, 0);
//   }

//   if (*token == gql_i_name)
//   {
//     pieces[1] = gql_extract_from_doc(doc, scanner);
//     *token = gql_next_token(doc, scanner, 0);
//   }

//   while (*token == gql_i_directive)
//   {
//     // To implement
//   }

//   if (*token == gql_is_op_curly)
//   {
//     // To implement
//   }

//   if (*token != gql_is_cl_curly || *token != gql_i_eof)
//   {
//     *token = gql_i_unknown;
//   }

//   return rb_ary_new4(4, pieces);
// }

// VALUE
// gql_parse_standard_execution(int argc, VALUE *argv, VALUE self)
// {
//   VALUE document, with_comments;
//   rb_scan_args(argc, argv, "11", &document, &with_comments);

//   if (!RB_TYPE_P(document, T_STRING))
//   {
//     rb_raise(rb_eArgError, "%+" PRIsVALUE " is not a string", document);
//   }

//   // DOCUMENT [OPERATION*, FRAGMENT*]
//   VALUE pirces[] = {Qnil, Qnil};

//   enum gql_identifier token;
//   struct gql_scanner scanner = {0, 0, 1, 1, -1};
//   const char *doc = RSTRING_PTR(document);

//   while ((token = gql_next_token(doc, &scanner, 1)) != gql_i_eof)
//   {
//     if (QGL_I_OPERATION(token) || token == gql_is_op_curly)
//     {
//       GQL_PUTS("Current token: %d", token);
//       GQL_SAFE_PUSH(pirces[0], gql_parse_operation(doc, &scanner, &token));
//       GQL_PUTS("Did token changed? %d", token);
//       // element = rb_str_new2("operation");

//       // if (NIL_P(operations))
//       //   operations = rb_ary_new();

//       // rb_ary_push(operations, element);
//     }
//     else if (token == gql_ie_fragment)
//     {
//       GQL_PUTS("Found a fragment!");
//       GQL_PUTS(gql_read_from_doc(doc, &scanner));
//       // element = rb_str_new2("fragment");

//       // if (NIL_P(fragments))
//       //   fragments = rb_ary_new();

//       // rb_ary_push(fragments, element);
//     }
//     else if (token == gql_i_comment)
//     {
//       GQL_PUTS("Found a comment!");
//       GQL_PUTS(gql_read_from_doc(doc, &scanner));
//     }
//     else
//     {
//       GQL_PUTS("Found something else! %d", token);
//       // rb_raise(gql_eParserError, "Parse error!");
//     }
//   }

//   return rb_ary_new4(2, pirces);
// }

VALUE gql_parse_value(VALUE self, VALUE content)
{
  GQL_PUTS("Received: %s", RSTRING_PTR(content));
  struct gql_scanner scanner = gql_new_scanner(content);
  return gql_value_to_token(&scanner);
}

void Init_gql_parser()
{
  GQLParser = rb_define_module("GQLParser");
  // rb_define_singleton_method(GQLParser, "parse_execution", gql_parse_standard_execution, -1);
  rb_define_module_function(GQLParser, "parse_value", gql_parse_value, 1);

  QLGParserToken = rb_define_class_under(GQLParser, "Token", rb_path2class("SimpleDelegator"));
  rb_define_method(QLGParserToken, "inspect", gql_inspect_token, 0);
  rb_define_attr(QLGParserToken, "begin_line", 1, 0);
  rb_define_attr(QLGParserToken, "begin_column", 1, 0);
  rb_define_attr(QLGParserToken, "end_line", 1, 0);
  rb_define_attr(QLGParserToken, "end_column", 1, 0);
  rb_define_attr(QLGParserToken, "type", 1, 0);

  gql_eParserError = rb_define_class_under(GQLParser, "ParserError", rb_eStandardError);
}
