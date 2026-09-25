# Translations

SkillUp is written in English, and every phrase it shows goes through `L["..."]`, so a phrase nobody has
translated just stays English.

To add your language, copy `phrases.txt` to `<locale>.lua` (deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU,
zhCN or zhTW), change `deDE` at the top to your locale, and translate the text on the right of each line. Keep
the `%d` and `%s` bits; `%2$s` style numbering works if your word order needs it. Then add
`Locales\<locale>.lua` to `SkillUpForever.toc` on the line after `Locales\enUS.lua` and open a pull request.
If that's a hassle, paste the file into an issue and I'll add it.
