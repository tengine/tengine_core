# -*- coding: utf-8 -*-

# puts "caller:\n  " << caller.join("\n  ")

# p1 = proc{ }
# filepath, lineno = *p1.source_location
# puts "=" * 100
# puts "Encoding.default_external:" << Encoding.default_external.inspect
# puts "Encoding.default_internal:" << Encoding.default_internal.inspect

# puts "__FILE__         : #{__FILE__}"
# puts "__FILE__.inspect : #{__FILE__.inspect}"
# puts "__FILE__.encoding: #{__FILE__.encoding.inspect}"


# puts "filepath         : #{filepath}"
# puts "filepath.inspect : #{filepath.inspect}"
# puts "filepath.encoding: #{filepath.encoding.inspect}"

# begin
#   encoded = filepath.encode(Encoding::UTF_8_MAC,Encoding::UTF_8)
#   puts "encoded         : #{encoded}"
#   puts "encoded.inspect : #{encoded.inspect}"
#   puts "encoded.encoding: #{encoded.encoding.inspect}"
# rescue Exception
#   puts "#{$!.class} #{$!.message}"
# end

require 'tengine/core'

driver :driver_in_multibyte_path_dir do

  # イベントに対して処理Aと処理Bを実行する
  on:event01 do
    puts "handler01"
  end

end
