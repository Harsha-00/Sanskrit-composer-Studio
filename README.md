# Sanskrit Composer Studio · संस्कृत-रचना-मञ्जूषा

A Sanskrit writing studio that runs on your own computer and opens in your web browser. It has:

* an editor with phonetic typing (ITRANS, Harvard-Kyoto, SLP1 and more) and live chandas scanning
* a word inspector
* 19 dictionaries, 757,713 entries in all
* the Aṣṭādhyāyī with its commentaries
* the Dhātupāṭha and Śabdapāṭha tables
* the kośas
* sandhi and declension tools
* a Reader for PDF and text files with dictionary lookup beside them

Everything runs locally: no account, and nothing is uploaded. Buttons marked ↗ open the same item on
[ashtadhyayi.com](https://ashtadhyayi.com/) or the
[Andhra Bharati Sanskrit dictionary](https://www.andhrabharati.com/dictionary/sanskrit/).

## Install

1. Download **`SanskritComposerStudio-<version>.zip`** from the
   [latest release](../../releases/latest).
2. Unzip it. Keep the folder anywhere you like; it needs about 1 GB.
3. Double-click the Start file for your computer. The Studio opens in your browser at
   http://127.0.0.1:4567. Keep the small window that appears open while you use it; close it to stop.

| Computer | Start file | Notes |
|---|---|---|
| Windows 10/11 | `Start Sanskrit Studio (Windows).bat` | Ruby and sqlite3 are included. If Windows says "Windows protected your PC", choose *More info → Run anyway*. |
| macOS | `Start Sanskrit Studio (Mac).command` | Uses the Ruby and sqlite3 built into macOS. The first time, right-click the file and choose *Open*, then *Open* again (it is not from the App Store). |
| Linux | `start-sanskrit-studio-linux.sh` | Install Ruby and sqlite3 first, e.g. `sudo apt install ruby sqlite3`, then run `sh start-sanskrit-studio-linux.sh`. |

Your documents are ordinary text files: Open… reads one from your computer, and Save downloads it. Unsaved
work is kept in the browser as a draft.

## Credits and thanks

This Studio exists because of the work of others. The **Credits & Thanks** page inside the app gives the
details.

* **[ashtadhyayi.com](https://ashtadhyayi.com/)**, by Neelesh Bodas. The sūtrapāṭha with its commentaries,
  the Dhātupāṭha and its forms, the Śabdapāṭha, prakriyā, gaṇapāṭha, uṇādi, liṅgānuśāsana, śikṣā and
  seven kośas come from its public data repository,
  [ashtadhyayi-com/data](https://github.com/ashtadhyayi-com/data). For everything else (more
  commentaries, Mahābhāṣya, audio, courses) and for corrections, please use ashtadhyayi.com itself.
* **[Andhra Bharati](https://www.andhrabharati.com/dictionary/sanskrit/)**. The Studio offers the twelve
  dictionaries its Sanskrit dictionary page brings together, and its character map follows the spirit of
  Andhra Bharati's Font Help. Nothing from andhrabharati.com is copied; the Studio links to it.
* **[Cologne Digital Sanskrit Lexicon](https://www.sanskrit-lexicon.uni-koeln.de/)**, Cologne University.
  The texts of those twelve dictionaries: Monier-Williams, Apte, Wilson, Benfey, Vaidya, Cappeller,
  Macdonell, Śabdakalpadruma, Vācaspatyam and three English-Sanskrit dictionaries. They are licensed
  CC BY-SA 4.0 (see `data/LICENSE-Cologne.txt`).
* **[Vidyut](https://github.com/ambuda-org/vidyut)** (Ambuda), whose prakriyā engine generated the verb
  forms; **[PDF.js](https://mozilla.github.io/pdf.js/)** (Mozilla, Apache-2.0); **WEBrick** (BSD-2-Clause);
  on Windows, **[RubyInstaller](https://rubyinstaller.org/)** and **[SQLite](https://sqlite.org/)** (public
  domain).

The sandhi joiner and splitter, the chandas scanner, the declension generator and the Telugu/IAST
renderings are computed by this Studio's own rules. Mistakes in them are ours, not the sources'.

## For developers

```bash
unzip sanskrit-studio-data-v1.zip -d data   # from the data-v1 release; see data/README.md
ruby lib/server.rb                          # http://127.0.0.1:4567 (Ruby 3 also needs: gem install webrick)
sh scripts/smoke_test.sh http://127.0.0.1:4567
```

* Environment variables: `PORT`, `BIND_ADDRESS`, `REFERENCE_DB`, `CDSL_DB`, `SQLITE3`, `OPEN_BROWSER=1`.
* **Releases:** push a tag such as `v1.0.0`. `.github/workflows/release.yml` builds the zip with
  `scripts/package.sh`, starts it with each launcher on Windows, macOS and Linux, runs the smoke test,
  and attaches the zip to the release.
* **Hosting it as a website instead:** the `Dockerfile` serves the same app on port 7860.
