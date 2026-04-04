Feature: Ikkunan koon muuttaminen
  Kayttajana haluan muuttaa macmd-ikkunan kokoa vapaasti
  jotta voin sovittaa tyotilan nayttooni.

  Scenario: Ikkuna skaalautuu raahaamalla
    Given macmd on auki tiedoston kanssa
    When raahaan ikkunan reunaa kokoon 600x400
    Then ikkunan koko on noin 600x400
    And editorin sisalto tayttaa ikkunan

  Scenario: Ikkuna voidaan maksimoida
    Given macmd on auki tiedoston kanssa
    When klikkaan vihreaa zoom-nappia
    Then ikkuna tayttaa nayton
    And editorin sisalto tayttaa ikkunan

  Scenario: Ikkuna kunnioittaa minimikokoa
    Given macmd on auki tiedoston kanssa
    When yritan pienentaa ikkunaa alle 400x300
    Then ikkuna ei pienene alle minimikoon

  Scenario: Editorin sisalto mukautuu ikkunan kokoon
    Given macmd on auki pitkan markdown-tiedoston kanssa
    When muutan ikkunan leveyden 1000px:sta 500px:iin
    Then teksti rivittyy uudelleen kapeampaan leveyteen
    And normaali proosateksti ei nayta vaakasuuntaista vierityspalkkia
