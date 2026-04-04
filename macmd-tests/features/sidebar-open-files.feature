Feature: Avoimet tiedostot sidebarissa
  Kayttajana haluan nahda kaikki avoimet dokumenttini sidebarissa
  jotta voin nopeasti vaihtaa niiden valilla.

  Scenario: Sidebar nayttaa avoimen tiedoston
    Given macmd:ssa on hello.md auki
    Then sidebar nayttaa "Open Files" -osion
    And "hello.md" nakyy Open Files -listassa

  Scenario: Toisen tiedoston avaaminen lisaa sen listaan
    Given macmd:ssa on hello.md auki
    When avaan world.md
    Then Open Files -lista nayttaa "hello.md" ja "world.md"

  Scenario: Klikkaus vaihtaa aktiivisen tabin
    Given Open Files -listassa on hello.md ja world.md
    When klikkaan "hello.md" listassa
    Then editori nayttaa hello.md sisallon
    And "hello.md" on korostettu sidebarissa

  Scenario: Dokumentin sulkeminen poistaa sen listasta
    Given macmd:ssa on hello.md ja world.md auki
    When suljen world.md
    Then vain "hello.md" nakyy Open Files -listassa
