# -*- coding: utf-8 -*-

p1 = proc{ }
filepath, lineno = *p1.source_location
puts "Encoding.default_external:" << Encoding.default_external.inspect
puts "Encoding.default_internal:" << Encoding.default_internal.inspect

puts "__FILE__         : #{__FILE__}"
puts "__FILE__.inspect : #{__FILE__.inspect}"
puts "__FILE__.encoding: #{__FILE__.encoding.inspect}"

puts "filepath         : #{filepath}"
puts "filepath.inspect : #{filepath.inspect}"
puts "filepath.encoding: #{filepath.encoding.inspect}"

begin
  encoded = filepath.encode(Encoding::UTF_8_MAC,Encoding::UTF_8)
  puts "encoded         : #{encoded}"
  puts "encoded.inspect : #{encoded.inspect}"
  puts "encoded.encoding: #{encoded.encoding.inspect}"
rescue Exception
  puts "#{$!.class} #{$!.message}"
end

f = "非ACSIIのディレクトリ名/非ASCIIのファイル名_dsl.rb"
puts "f         : #{f}"
puts "f.inspect : #{f.inspect}"
puts "f.encoding: #{f.encoding.inspect}"

content = File.read(f)
puts "content         : #{content}"
puts "content.inspect : #{content.inspect}"
puts "content.encoding: #{content.encoding.inspect}"

self.instance_eval(content, f)
