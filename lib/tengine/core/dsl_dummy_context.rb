# -*- coding: utf-8 -*-
class Tengine::Core::DslDummyContext
  # rspecでテストを行うにあたり、Object.should_receive(:new)すると、「stack level too deep」でテストが失敗してしまいます。
  # テストを通すためにこのクラスを作成しました。
  # 上記以外の責務はありません。
end
