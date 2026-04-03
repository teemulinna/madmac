Feature: File saving and autosave
  As a user editing a markdown document
  I want my changes to be saved automatically
  So that I never lose work

  Background:
    Given macmd is running
    And a markdown file is open

  Scenario: Autosave triggers automatically
    Given I make changes to the document
    When I wait for the autosave interval
    Then the file on disk should contain my changes
    And no manual save action should be required

  Scenario: Manual save with Cmd+S
    Given I make changes to the document
    When I press Cmd+S
    Then the file on disk should be updated immediately
    And the window title should not show unsaved indicator

  Scenario: Dirty state indicator
    Given the document has no unsaved changes
    When I type new text
    Then the window close button should show a dot indicator
    When I press Cmd+S
    Then the dot indicator should disappear

  Scenario: Version history via macOS Versions
    Given I have made and saved several changes over time
    When I select File > Revert To > Browse All Versions
    Then the macOS Versions interface should appear
    And I should be able to browse previous versions

  Scenario: Crash recovery
    Given I have made unsaved changes
    When macmd terminates unexpectedly
    And I relaunch macmd
    Then the document should be restored with my unsaved changes
    And a recovery notification should be shown

  Scenario: Save new untitled document
    Given I create a new document with File > New
    And I type some content
    When I press Cmd+S
    Then a save dialog should appear
    And I should be able to choose location and filename
    And the file should be saved as UTF-8 encoded .md

  Scenario: Save preserves original line endings
    Given I open a file with LF line endings
    When I make changes and save
    Then the saved file should still use LF line endings
