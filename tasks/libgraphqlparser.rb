# frozen_string_literal: true

require 'pathname'
require 'fileutils'
require 'rake/extensiontask'

require 'pry'

gem_spec = Gem::Specification.load('rails-graphql.gemspec')
Rake::ExtensionTask.new(:graphqlparser, gem_spec) do |ext|
  ext.name = 'graphqlparser'
  ext.ext_dir = 'ext'
  ext.lib_dir = 'lib'
  ext.cross_compile = true
  ext.cross_platform = %w[x86-mingw32 x64-mingw32]

  # Link C++ stdlib statically when building binary gems.
  ext.cross_config_options << '--enable-static-stdlib'
  ext.cross_config_options << '--disable-march-tune-native'

  ext.cross_compiling do |spec|
    spec.files.reject! { |path| File.fnmatch?('ext/*', path) }
  end
end

namespace :precompile do
  MIN_PYTHON_VERSION = 2
  GET_PYTHON_VERSION = 'import platform; major, minor, patch = platform.python_version_tuple(); print(major);'

  BASE_PATH = Pathname.new(__dir__)
  EXTENSION_PATH = BASE_PATH.join('../ext/libgraphqlparser').expand_path
  PRECOMPILE_PATH = BASE_PATH.join('../ext/graphqlparser').expand_path

  desc 'Prepare the parser to be compiled'
  task :parser do
    python = ensure_python!
    ensure_destination!
    precompile_files(python)
    copy_other_libs!
    save_version!
  rescue => e
    print_nok(e.message)
  end

  private

  def ensure_python!
    print_step 'Checking python'

    exe = %x[which python | grep "/python"].chomp
    raise 'To precompile this gem you will need a python executable' if exe.empty?

    version = %x[#{exe} -c '#{GET_PYTHON_VERSION}'].chomp.to_i
    raise 'At least a Python version 2 is necessary' if version < MIN_PYTHON_VERSION

    print_ok "Found version #{version}"
    exe
  end

  def ensure_destination!
    print_step 'Creating destination folder'
    FileUtils.rm_rf(PRECOMPILE_PATH.to_s) if PRECOMPILE_PATH.exist?
    FileUtils.mkdir(PRECOMPILE_PATH.to_s)
    FileUtils.mkdir(PRECOMPILE_PATH.join('c').to_s)
    FileUtils.mkdir(PRECOMPILE_PATH.join('parsergen').to_s)
    print_ok
  end

  def precompile_files(exe)
    print_step 'Pre-compiling py files'
    {
      'Ast.h'                             => 'cxx',
      'AstVisitor.h'                      => 'cxx_visitor',
      'Ast.cpp'                           => 'cxx_impl',
      'c/GraphQLAst.h'                    => 'c',
      'c/GraphQLAst.cpp'                  => 'c_impl',
      'c/GraphQLAstForEachConcreteType.h' => 'c_visitor_impl',
      'JsonVisitor.h.inc'                 => 'cxx_json_visitor_header',
      'JsonVisitor.cpp.inc'               => 'cxx_json_visitor_impl',
    }.each { |file, type| precompile_file(exe, type, file) }
    print_ok
  end

  def precompile_file(exe, type, name)
    command = "#{exe} #{EXTENSION_PATH}/ast/ast.py"
    command += " #{type} #{EXTENSION_PATH}/ast/ast.ast"
    command += " > #{PRECOMPILE_PATH}/#{name}"
    raise "Unable to precompile #{name}" unless system(command)
  end

  def copy_other_libs!
    print_step 'Copying libs'
    %w[
      AstNode.h
      dump_json_ast.cpp
      GraphQLParser.cpp
      GraphQLParser.h
      JsonVisitor.cpp
      JsonVisitor.h
      lexer.lpp
      parser.ypp
      syntaxdefs.h
      c/GraphQLAstNode.cpp
      c/GraphQLAstNode.h
      c/GraphQLAstToJSON.cpp
      c/GraphQLAstToJSON.h
      c/GraphQLAstVisitor.cpp
      c/GraphQLAstVisitor.h
      c/GraphQLParser.cpp
      c/GraphQLParser.h
      parsergen/lexer.cpp
      parsergen/lexer.h
      parsergen/location.hh
      parsergen/parser.tab.cpp
      parsergen/parser.tab.hpp
      parsergen/position.hh
      parsergen/stack.hh
    ].each do |file_name|
      FileUtils.cp(
        EXTENSION_PATH.join(file_name).to_s,
        PRECOMPILE_PATH.join(file_name).to_s,
      ) rescue raise "Unable to copy #{file_name}"
    end
    print_ok("Libs available in #{PRECOMPILE_PATH}")
  end

  def save_version!
    print_step 'Creating VERSION file'
    version = Dir.chdir(EXTENSION_PATH) do
      %x[git describe --abbrev=4 --dirty --always --tags].chomp
    end.split('-').first
    PRECOMPILE_PATH.join('VERSION').write(version)
    print_ok(version)
  end

  def print_step(name)
    puts "#{name.ljust(30)} [\033[s   ] "
  end

  def print_ok(extra = nil)
    print "\033[u\033[1A\e[1m\033[K\e[32m ✓\e[0m] "
    print "#{extra}" unless extra.nil?
    puts
  end

  def print_nok(message)
    puts "\033[u\033[1A\e[1m\033[K\e[31m ✗\e[0m] #{message}"
  end
end
