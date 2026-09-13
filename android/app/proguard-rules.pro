# Vosk (音声認識) が使用する JNA 関連クラスを難読化・除去しないためのルール
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }
