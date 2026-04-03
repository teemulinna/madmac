Feature: Opening markdown files
  As a macOS user who double-clicks a .md file in Finder
  I want to see the file opened in macmd
  So that I can read markdown documents natively

  Background:
    Given macmd is installed and registered as the default .md handler

  Scenario: Open a simple markdown file from Finder
    Given a file "hello.md" exists with content:
      """
      # Hello World

      This is a **simple** markdown file.
      """
    When I open "hello.md" with macmd
    Then a new window should appear
    And the window title should contain "hello"
    And the document should be displayed in Reading Mode

  Scenario: Open a file via File > Open menu
    Given macmd is running
    When I select File > Open from the menu
    And I choose a markdown file
    Then the file should open in a new window
    And the document should be displayed in Reading Mode

  Scenario: Open a recently opened file
    Given I have previously opened "notes.md"
    When I select File > Open Recent
    Then "notes.md" should appear in the recent files list
    When I click on "notes.md"
    Then the file should open in a new window

  Scenario: Open a file with UTF-8 content
    Given a file "unicode.md" exists with UTF-8 content including:
      | Language | Sample |
      | Finnish  | Hyvää päivää |
      | Japanese | こんにちは |
      | Emoji    | 🎉 🚀 ✅ |
    When I open "unicode.md" with macmd
    Then all characters should render correctly
    And no encoding errors should be displayed

  Scenario: Open a non-UTF-8 file shows error
    Given a file "latin1.md" exists encoded in ISO-8859-1
    When I open "latin1.md" with macmd
    Then an error message should indicate the file is not UTF-8
    And the window should not display garbled text

  Scenario: Open a large markdown file
    Given a file "large.md" exists with 10000 lines of markdown
    When I open "large.md" with macmd
    Then the file should open in under 500 milliseconds
    And scrolling should be smooth at 60fps

  Scenario: Open multiple files simultaneously
    Given files "a.md" and "b.md" exist
    When I open both files with macmd
    Then two separate windows should appear
    And each window should display its respective file

  Scenario: Registered UTType for markdown extensions
    Given macmd is installed
    Then macmd should be registered as a handler for:
      | Extension  |
      | .md        |
      | .markdown  |
