Feature: Theme and appearance
  As a macOS user
  I want macmd to follow my system appearance settings
  So that the editor looks native and comfortable

  Scenario: Light mode follows system
    Given the system appearance is set to Light
    When I open a markdown file in macmd
    Then the editor background should be light
    And the text should be dark
    And code blocks should have a light gray background

  Scenario: Dark mode follows system
    Given the system appearance is set to Dark
    When I open a markdown file in macmd
    Then the editor background should be dark
    And the text should be light
    And code blocks should have a darker background

  Scenario: Appearance changes live
    Given macmd is running with a file open
    When I switch the system appearance from Light to Dark
    Then the editor should transition to dark theme
    And no restart should be required

  Scenario: Typography is readable and pleasant
    Given a markdown file is open in Reading Mode
    Then body text should use a proportional serif or sans-serif font
    And code should use a monospace font
    And line height should be at least 1.5x the font size
    And paragraph spacing should provide clear visual separation
    And the maximum content width should not exceed 80 characters
