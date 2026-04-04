Feature: Ikkunoiden palautus kaynnistyksessa
  Kayttajana haluan etta macmd palauttaa edellisen session dokumentit
  mutta ei avaa tiedostoja joita en ollut avannut.

  Scenario: Viimeksi auki olleet dokumentit palautuvat
    Given macmd:ssa oli hello.md ja notes.md auki
    And macmd suljettiin normaalisti
    When kaynistan macmd:n uudelleen
    Then hello.md ja notes.md avautuvat automaattisesti

  Scenario: Tiedostoja joita ei ollut auki ei avata
    Given macmd:ssa oli vain hello.md auki
    And demo.md ei ollut auki
    And macmd suljettiin normaalisti
    When kaynistan macmd:n uudelleen
    Then hello.md avautuu
    But demo.md ei avaudu

  Scenario: Tiedoston avaaminen tuoreen kaynnistyksen jalkeen
    Given macmd kaynnistyi
    When avaan markdown-tiedoston
    Then tasmallen yksi ikkuna ilmestyy kyseiselle tiedostolle
    And ikkunan otsikko nayttaa tiedostonimen
