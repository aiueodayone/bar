# Vosk (音声認識) が使用する JNA 関連クラスを難読化・除去しないためのルール
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }

# JNA はデスクトップ Java 向けの AWT 連携コード(未使用)を内部で参照しており、
# Android には java.awt.* が存在しないため R8 が "Missing class" として
# ビルドを失敗させる。この経路は Android では実行されないため無視してよい。
-dontwarn java.awt.**
