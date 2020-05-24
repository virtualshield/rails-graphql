# frozen_string_literal: true

gem_root = File.expand_path('..', __dir__)
precomp_dir = File.join(gem_root, 'ext', 'graphqlparser')

abort 'The libgraphqlparser must be pre-compile first!' \
  unless File.directory?(precomp_dir)

require 'mkmf'

# Define a version variable
version = File.read(File.join(precomp_dir, 'VERSION'))
$defs << "-DGRAPHQLPARSER_VERSION=\\\"#{version}\\\""

# Set necessary flags and includes
$CXXFLAGS << ' -std=c++11' << ' -g' << ' -Wall'

# Enable maintainer mode for better log
if ENV['MAINTAINER_MODE']
  require 'pry'

  $stderr.puts 'Maintainer mode enabled'
  $CFLAGS << ' -ggdb' << ' -DDEBUG' << ' -pedantic'
end

# Disable noisy compilation warnings.
$warnflags = ''
$CFLAGS.gsub!(/[\s+](-ansi|-std=[^\s]+)/, '')

$VPATH << "$(srcdir)/graphqlparser/"
$VPATH << "$(srcdir)/graphqlparser/c/"
$VPATH << "$(srcdir)/graphqlparser/parsergen/"

$INCFLAGS << " -I$(srcdir)/graphqlparser/"
$INCFLAGS << " -I$(srcdir)/graphqlparser/c/"
$INCFLAGS << " -I$(srcdir)/graphqlparser/parsergen/"

$srcs = [
  File.join(precomp_dir, 'Ast.cpp'),
  File.join(precomp_dir, 'JsonVisitor.cpp'),
  File.join(precomp_dir, 'GraphQLParser.cpp'),
  File.join(precomp_dir, 'parsergen', 'parser.tab.cpp'),
  File.join(precomp_dir, 'parsergen', 'lexer.cpp'),
  File.join(precomp_dir, 'c', 'GraphQLAstToJSON.cpp'),
]

create_header
create_makefile 'graphqlparser'
