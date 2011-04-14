# Copyright (c) 2011 VMware, Inc.  All Rights Reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'trollop'

module RVC

class OptionParser < Trollop::Parser
  attr_reader :applicable

  def initialize cmd, &b
    @cmd = cmd
    @summary = nil
    @args = []
    @has_options = false
    @seen_not_required = false
    @seen_multi = false
    @applicable = Set.new
    super &b
  end

  def summary str
    @summary = str
    text str
  end

  def summary?
    @summary
  end

  def opt name, *a
    super
    @applicable << @specs[name][:lookup] if @specs[name][:lookup]
    @has_options = true unless name == :help
  end

  def has_options?
    @has_options
  end

  def arg name, description, spec={}
    spec = {
      :description => description,
      :required => true,
      :default => nil,
      :multi => false,
    }.merge spec
    spec[:default] = [] if spec[:multi] and spec[:default].nil?
    fail "Multi argument must be the last one" if @seen_multi
    fail "Can't have required argument after optional ones" if spec[:required] and @seen_not_required
    fail "lookup and lookup_parent are mutually exclusive" if spec[:lookup] and spec[:lookup_parent]
    [:lookup, :lookup_parent].each do |sym|
      if spec[sym].is_a? Enumerable
        spec[sym].each { |x| @applicable << x }
      elsif spec[sym]
        @applicable << spec[sym]
      end
    end
    @args << [name,spec]
    text "  #{name}: " + [description, spec[:lookup], spec[:lookup_parent]].compact.join(' ')
  end

  def parse argv
    opts = super argv

    @specs.each do |name,spec|
      next unless klass = spec[:lookup] and path = opts[name]
      opts[name] = lookup_single! path, klass
    end

    argv = leftovers
    args = []
    @args.each do |name,spec|
      if spec[:multi]
        err "missing argument '#{name}'" if spec[:required] and argv.empty?
        a = (argv.empty? ? spec[:default] : argv.dup)
        a = a.map { |x| postprocess_arg x, spec }.inject([], :+)
        err "no matches for '#{name}'" if spec[:required] and a.empty?
        args << a
        argv.clear
      else
        x = argv.shift
        err "missing argument '#{name}'" if spec[:required] and x.nil?
        x = spec[:default] if x.nil?
        a = x.nil? ? [] : postprocess_arg(x, spec)
        err "more than one match for #{name}" if a.size > 1
        err "no match for '#{name}'" if spec[:required] and a.empty?
        args << a.first
      end
    end
    err "too many arguments" unless argv.empty?
    return args, opts
  end

  def postprocess_arg x, spec
    if spec[:lookup]
      lookup! x, spec[:lookup]
    elsif spec[:lookup_parent]
      lookup!(File.dirname(x), spec[:lookup_parent]).map { |y| [y, File.basename(x)] }
    else
      [x]
    end
  end

  def educate
    arg_texts = @args.map do |name,spec|
      text = name
      text = "[#{text}]" if not spec[:required]
      text = "#{text}..." if spec[:multi]
      text
    end
    arg_texts.unshift "[opts]" if has_options?
    puts "usage: #{@cmd} #{arg_texts*' '}"
    super
  end
end

end
