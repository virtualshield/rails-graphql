#include "ruby.h"

#define GQL_SAFE_PUSH_AND_NEXT(source, scanner, action) ({ \
  GQL_SAFE_PUSH(source, action);                           \
  gql_next_lexeme_no_comments(scanner);                    \
})
#define GQL_ASSIGN_TOKEN_AND_NEXT(source, scanner) (GQL_ASSIGN_VALUE_AND_NEXT(source, scanner, gql_scanner_to_token(scanner)))
#define GQL_ASSIGN_VALUE_AND_NEXT(source, scanner, value) ({ \
  source = value;                                            \
  gql_next_lexeme_no_comments(scanner);                      \
})
#define GQL_BUILD_PARSE_OUTER_TOKEN(type, size, pieces, scanner, mem) ({            \
  gql_token_start_from_mem(GQL_BUILD_PARSE_TOKEN(type, size, pieces, scanner), mem); \
})
#define GQL_BUILD_PARSE_TOKEN(type, size, pieces, scanner) ({                    \
  gql_set_token_type(gql_as_token(rb_ary_new4(size, pieces), scanner, 0), type); \
})

VALUE GQLParser;
VALUE QLGParserToken;
VALUE gql_eParserError;
