Feature: Natiivit macOS-dokumenttitabit
  Kayttajana haluan dokumenttien avautuvan tabeina yhteen ikkunaan
  jotta voin jarjestaa tyotilaani kuten muissa macOS-sovelluksissa.

  Scenario: Toinen dokumentti aukeaa tabina
    Given macmd:ssa on file-a.md auki
    When avaan file-b.md
    Then file-b.md ilmestyy tabiksi samaan ikkunaan
    And tabipalkki nayttaa molemmat tiedostot

  Scenario: Tabien vaihto nayttaa oikean sisallon
    Given macmd:ssa on file-a.md ja file-b.md tabissa
    When klikkaan file-a.md tabia
    Then editori nayttaa file-a.md sisallon
    When klikkaan file-b.md tabia
    Then editori nayttaa file-b.md sisallon

  Scenario: Tabin sulkeminen jattaa muut tabit
    Given macmd:ssa on file-a.md ja file-b.md tabissa
    When suljen file-b.md tabin
    Then file-a.md pysyy nakyvissa
    And tabipalkki nayttaa vain file-a.md

  Scenario: Cmd+N luo uuden tabin
    Given macmd:ssa on tiedosto auki
    When painan Cmd+N
    Then uusi nimeamaton tabi ilmestyy
    And uusi tabi on edit-modessa

  Scenario: Tabin otsikko paivittyy tallennettaessa
    Given macmd:ssa on nimeamaton dokumentti auki tabissa
    When tallennan dokumentin nimella "muistiinpanot.md"
    Then tabin otsikko paivittyy muotoon "muistiinpanot.md"

  Scenario: Tabi voidaan irrottaa omaksi ikkunaksi
    Given macmd:ssa on kaksi tabia auki
    When raahaan tabin pois tabipalkista
    Then tabi muuttuu omaksi ikkunaksi
    And uudella ikkunalla on oma sidebar
