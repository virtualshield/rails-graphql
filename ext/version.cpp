/**
 * Copyright 2020-present, VirtualShield
 *
 * This ensures GraphQL headers and provides minimal ruby initialization
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include "ruby.h"

#include "c/GraphQLParser.cpp"

extern "C" {
  void Init_graphqlparser() {
    const char *version = GRAPHQLPARSER_VERSION;

    VALUE mod = rb_define_module("GQLAst");
    rb_define_const(mod, "VERSION", rb_str_new(version, strlen(version)));
  }
}
