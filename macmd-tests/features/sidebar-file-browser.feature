Feature: Tiedostoselain sidebarissa
  Kayttajana haluan selata markdown-tiedostoja avoimen dokumentin lahella
  jotta voin nopeasti avata niihin liittyvia tiedostoja.

  Scenario: Selain nayttaa parent-hakemiston md-tiedostot
    Given avaan /path/to/project/readme.md
    Then sidebar nayttaa "Files" -osion
    And se listaa .md-tiedostot hakemistosta /path/to/project/

  Scenario: Vain markdown-tiedostot naytetaan
    Given hakemistossa on readme.md, notes.md ja image.png
    Then Files-osio nayttaa readme.md ja notes.md
    And image.png ei nay

  Scenario: Tiedoston klikkaus avaa sen
    Given Files-osiossa nakyy notes.md
    When klikkaan "notes.md" Files-osiossa
    Then notes.md avautuu editoriin
    And "notes.md" ilmestyy Open Files -listaan

  Scenario: FSEvents paivittaa listan reaaliajassa
    Given macmd nayttaa tiedostoja hakemistosta
    When luon uuden tiedoston "uusi.md" hakemistoon
    Then "uusi.md" ilmestyy Files-osioon 2 sekunnissa

  Scenario: Open Folder vaihtaa juuren
    Given macmd on auki
    When valitsen File > Open Folder ja valitsen /path/to/docs/
    Then Files-osio nayttaa .md-tiedostot hakemistosta /path/to/docs/
    And alihakemistot natetaan laajennettavina

  Scenario: Juurikansio muistuu uudelleenkaynnistyksen yli
    Given olen valinnut Open Folderilla hakemiston /path/to/docs/
    And macmd suljettiin ja kaynnistettiin uudelleen
    Then Files-osio nayttaa edelleen /path/to/docs/ sisallon
