# -*- coding: utf-8 -*-
# 使い方
# テスト実行時に 環境変数MONGO_INDEX_KEY_LOGにログの出力先のファイル名を指定しておくと、
# そこにmongoに対してどんな検索条件やソート、ヒントなどをどのように指定しているのかを出力できます
#
# この出力された結果のファイルに対して sort と uniq をかけることにより、どんなインデックスを
# 作れば良いのか判断する材料となります。
#
# export MONGO_INDEX_KEY_LOG=$HOME/tmp/mongo_index_key.log
# cd tenigne_core && rake spec
# cd tenigne_resource && rake spec
# cd tenigne_job && rake spec
# cd tenigne_console && rake spec
# cd $HOME/tmp
# cat mongo_index_key.log | sort | uniq > mongo_index_key_summary.log
#
# これで $HOME/tmp/mongo_index_key_summary.log にどのようなキーが使われているのかがまとめられます
# 
if ENV['MONGO_INDEX_KEY_LOG']
  file_path = File.expand_path(ENV['MONGO_INDEX_KEY_LOG'])
  STDOUT.puts("MONGO_INDEX_KEY_LOG enable logging key infomation for index to #{file_path}")

  Mongo::Collection.class_eval do
    def index_key_log_file
      unless defined?(@@index_key_log_file)
        file_path = File.expand_path(ENV['MONGO_INDEX_KEY_LOG'])
        @@index_key_log_file = File.open(file_path, "a")
      end
      @@index_key_log_file
    end

    def find_with_index_key_log(selector={}, opts={}, &block)
      index_key_log_file.puts("#{self.name}.find({#{_hash_keys_(selector)}}, {#{_hash_keys_(opts.dup)}})")
      find_without_index_key_log(selector, opts, &block)
    end
    alias_method :find_without_index_key_log, :find
    alias_method :find, :find_with_index_key_log


    def find_and_modify_with_index_key_log(opts={}, &block)
      o = opts.dup
      query = o.delete(:query)
      index_key_log_file.puts("#{self.name}.find_and_modify({#{_hash_keys_(query)}}, {#{_hash_keys_(o)}})")
      find_and_modify_without_index_key_log(opts, &block)
    end
    alias_method :find_and_modify_without_index_key_log, :find_and_modify
    alias_method :find_and_modify, :find_and_modify_with_index_key_log

    def _hash_keys_(hash)
      res = []
      if sort = hash.delete(:sort)
        res << ":sort => #{sort.inspect}"
      end
      if hint = hash.delete(:hint)
        res << ":hint => #{hint.inspect}"
      end
      res += hash.keys.map(&:inspect)
      res.join(',')
    end

  end

end
