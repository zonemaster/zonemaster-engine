# Instructions for translators

See the general [Translation] document for overall documentation on
translation.

### Table of contents
* [Software preparation]
* [Background]
* [Github preparation]
* [Tools]
* [Steps]
* [Adding a new language]

## Software preparation

For the steps below you need to work on a computer with Git, Perl and Gettext.
Select what OS you want to work on from the list below. Other OSs will also work, 
but you will have to find instructions elsewhere.

* CentOS

  To be written.

* Debian

  Install the following:
  ```
  apt install gettext git liblocale-po-perl
  ```

* FreeBSD

  Install the following:
  ```
  pkg install devel/gettext-tools devel/git-lite devel/p5-Locale-PO
  ```

* Ubuntu

  Install the following:
  ```
  apt install gettext git make liblocale-po-perl
  ```

##  Background

The first step in updating the translations is to generate a new template file
("Zonemaster-Engine.pot"). In practice you rarely need to think about generating 
it as it is generally performed as an implicit intermediate step.
If you do want to generate it, the command is `make extract-pot`.

The translated strings are maintained in files named "<LANG-CODE>.po". 
Currently there are the following files (and languages):
* da.po (Danish)
* fr.po (French)
* nb.po (Norwegian)
* sv.po (Swedish)

Execute `make xx.po` to update the *PO* file for language "xx". Choose the
language code for the language that you want to update. The command will
update the *PO* file with new message ids (*msgid*) from the source code. 
This should only be strictly necessary to do when a module has been added, 
changed or removed, but it it recommended to do this step every time.

Execute `make update-po` to update all the *PO* files with new message ids 
from the source code.

By default the updated *PO* file will suggested translations for new message 
ids based on fuzzy matching of similar strings. This is not always desirable 
and you can disable fuzzy matching by executing one of the following
commands instead:
  ```
  make xx.po MSGMERGE_OPTS=--no-fuzzy-mathing
  make update-po MSGMERGE_OPTS=--no-fuzzy-mathing
  ```

## Github preparation

For full integration with Zonemaster translation you need a Github account
and a fork of *Zonemaster-Engine*. If you do not have a Github account you
can easily create one at [Github]. If you are not prepared to
create one, contact the Zonemaster work group for instructions by sending
an email to "zonemaster@zonemaster.net".

To create a fork of *Zonemaster-Engine*: 
1. Go to [Zonemaster-Engine repository].
2. Make sure you are logged in at Github.
3. Press the "Fork" button.

Make sure that your public *ssh* key is uploaded to Github and that its
private key is available on the computer you are going to work from.

## Tools

The *PO* file can be edited with a plain text editor, but then it is 
important to keep the database structure of the file. There are tools that
makes editing of the *PO* files easier. When using those, the *PO* file is
handled as a database instead of as a plain file.

* There is an [add-on to Emacs][emacs PO-mode], which makes updating 
  and searching in the ".po" file easier and more robust.
* There is also "[GNOME Translation Editor]", a graphical PO editor 
  available for at least Windows and Linux.
* There are more tools available, either cloud services or programs
  for download, and they could be found by searching for "po editor".

## Clone preparation

You need a local clone of the repository to work in.

* Clone the Zonemaster-Engine repository, unless you already
  have a clone that you could reuse:
  ```
  git clone https://github.com/zonemaster/zonemaster-engine.git
  ```

* Enter the directory of the clone created above or already
  existing clone:
  ```
  cd zonemaster-engine
  ```

* If you already have an old clone of Zonemaster-Engine,
  run an update.
  ```
  git fetch --all
  ```

* Now it is time to connect your own fork of *Zonemaster-Engine*
  at Github to the created clone, unless you have alreday done that,
  in case you can skip the next step.

* You have a user name at Github. Here we use "xxxx" as your user name
  and also the name of the remote in clone on the local machine.
  ```
  git remote add xxxx git@github.com:xxxx/zonemaster-engine.git
  git fetch --all
  ```

## Translation steps

The steps in this section will work for most translation work. We
welcome comments on these.

* Check-out the *develop* branch and create a new branch to work in.
  You can call the new branch whatever you want, but here we use
  the name "translation-update". If that name is already taken,
  you have to give it a new name or remove the old branch.
  ```
  git checkout origin/develop
  git checkout -b translation-update
  ```

* Go to the *share* directory and run the update command for the *PO* file 
  for the language you are going to work with. Replace "xx" with the 
  language code in question. This should be done every time.
  ```
  cd share
  make xx.po
  ```

* The *PO* file is updated with new *msgids*, if any, and now you can start
  working with it.

* Update the *PO* file with the tool of your choice. See above. You can copy
  the *PO* file to another computer, edit it there, and then copy it back to
  your Zonemaster-Engine clone.

* When doing the update, do not change the *msgid*, only the *msgstr*. The 
  *msgid* cannot and must not be be update in this process. They are the
  links between the Perl module and the *PO* file.

* If you find a *msgid* that needs an update, create an [issue][new issue] 
  or a pull request to have the message updated in the Perl module. If you 
  create an issue, always include module and message tag, e.g. 
  "BASIC:NO_PARENT". And make a suggestion of the new *msgid*.

* Inspect every *fuzzy entry* (tagged with "fuzzy"). Update *msgstr*
  if needed and remove the "fuzzy" tag. The "fuzzy" tag must always be removed.

* Search for *untranslated entries* (empty *msgstr*) and add a
  translation. At the end of the file there could be *obsolete entries*
  (lines starting with "#~") and those could have matching translations,
  especially of the *msgid* has been changed.

* Any remaining *obsolete entries* (lines at the end of the file starting 
  with "#~") could be removed. They serve no purpose anymore.

* Check that the messages arguments in all *msgstr* strings match up with 
  those in the *msgid* strings.
  ```
  ../util/check-msg-args xx.po
  ```

* When the update is completed, it is time to commit the changes. You should
  only commit the "xx.po" file.
  ```
  git commit -m 'Write a description of the change' xx.po
  ```

* There could be other files changed or added that should not be included.
  Run the status command to see them.
  ```
  git status
  ```

* Other changed files could be reset by a "checkout". This could also
  be done before creating the commit.
  ```
  git checkout FILENAME
  ```

* Added files not needed can just be removed. This could also be done
  before the commit.
  ```
  rm FILE-NAME
  ```

* Now push the local branch you created to your fork at Github. 
  "translation-update" is name of the branch you created above and 
  have committed the updates to. Use your Github user name instead of
  "xxxx".
  ```
  git push -u xxxx translation-update
  ```

* Go to your fork at Github, https://github.com/xxxx/zonemaster-engine
  and use your Github user name instead of "xxxx".

* Select to create a new "pull request" where the base repository
  should be *zonemaster/zonemaster-engine* and the base branch should be
  *develop* (not *master*). The "head" should be your fork and "compare"
  the same branch as you created above and pushed to your fork,
  "translation-update".

* Inspect what Github says that will change by the pull request. It should
  only be the *PO* file that you have updated and nothing else. If additional
  files are listed, please correct or request for help.

* Press "create pull request", write a nice description and press "create"
  again.

* If you go back to your own computer and just keep the clone as it is, you
  can easily update the pull request if needed with more changes to the same
  *PO* file. When the pull request has been merged by the Zonemaster work group,
  you can delete the local clone and on your Github fork you can remove the 
  branch. Or keep them for next time.


## Adding a new language

If you want to add a new language, then follow the steps above with some 
modifications. Before you add a language contact the Zonemaster project
to discuss timeplan and other aspects of the new language. Every language must
be update each time a message is added or changed.

Above you found the following step that must now be modified, but run the
steps before this step:

> * Go to the *share* and update the *PO* file for the language you are going
>   to work with. Replace "xx" with the language code in question.
> ```
> cd share
> make xx.po
> ```

The new language is not there and cannot be updated. Instead you have to
create the new language file (*PO* file). The easiest way is to make a copy
of an existing file.

* Determine what the language code of the new language should be. I must be
  a code that is available in the *locale* system. Try the following commands
  to see if it is available. Replace "xx" with that code that you think it
  should be.
  ```
  locale -a | grep xx      # Works at least in FreeBSD
  grep xx /etc/locale.gen  # Works at least in Ubuntu 18.04
  ```

* Go to the *share* and update the *PO* file for some language, say Swedish,
  and make a copy of that to the new file name. And then reset the *PO* file
  for Swedish.
  ```
  cd share
  make sv.po
  cp sv.po xx.po
  git checkout sv.po
  ```

* You have to "add" the new file to git before you start working on it.
  ```
  git add xx.po
  ```

* When you do the update of the new *PO* file you have to replace all *msgstr*
  in Swedish with the translation in the new language, but also update the
  "Language" field in the header.

* Now you go back to the steps and continue in the same was with an existing
  language.


[Adding a new language]:             #adding-a-new-language
[Background]:                        #background
[Emacs PO-mode]:                     https://www.gnu.org/software/gettext/manual/html_node/PO-Mode.html#PO-Mode
[GNOME Translation Editor]:          https://wiki.gnome.org/Apps/Gtranslator
[Github preparation]:                #github-preparation
[Github]:                            https://github.com/
[Software preparation]:              #software-preparation
[Steps]:                             #steps
[Tools]:                             #tools
[Translation]:                       https://github.com/zonemaster/zonemaster-engine/blob/develop/docs/Translation.pod
[Zonemaster-Engine repository]:      https://github.com/zonemaster/zonemaster-engine
[new issue]:                         https://github.com/zonemaster/zonemaster-engine/issues/new








