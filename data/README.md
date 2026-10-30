# Data

The two databases are too large for the git repository (GitHub's limit is 100 MB per file). They are
published as `sanskrit-studio-data-v1.zip` on the repository's `data-v1` release, and every download
(`SanskritComposerStudio-<version>.zip`) already contains them. To run from a clone, unzip that file here.

| File | Contents | Source |
|---|---|---|
| `reference.sqlite` | sūtras with commentaries, dhātus and their forms, śabdas, prakriyā, gaṇapāṭha, uṇādi, liṅgānuśāsana, śikṣā, 7 kośas | [ashtadhyayi-com/data](https://github.com/ashtadhyayi-com/data) at commit `a9f9112` (`DATA_COMMIT.txt`) |
| `cologne.sqlite` | 12 dictionaries, 666,336 entries | [sanskrit-lexicon/csl-orig](https://github.com/sanskrit-lexicon/csl-orig), files verified by git blob SHA-1 (`cdsl_source_blob_shas.txt`); CC BY-SA 4.0, see `LICENSE-Cologne.txt` |

`SHA256SUMS` holds the checksums of the two databases; `scripts/package.sh` refuses data that does not
match it.

Both were built and checked by the tools in the offline Sanskrit Composer project
(`studio/scripts/build_database.rb`, `tools/build_dictionary_db.py`, `tools/crosscheck_headwords.py`).
