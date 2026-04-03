Feature: Fluid Mode inline editing
  As a user editing a markdown file
  I want to see rendered content that becomes editable on click
  So that I can focus on writing without split panes

  Background:
    Given macmd is running
    And a markdown file is open in Fluid Mode (Cmd+E)

  # --- Mode Toggle ---

  Scenario: Toggle between Reading Mode and Fluid Mode
    Given a markdown file is open in Reading Mode
    When I press Cmd+E
    Then the editor should switch to Fluid Mode
    When I press Cmd+E again
    Then the editor should switch back to Reading Mode

  Scenario: Mode indicator in status bar
    Given a markdown file is open
    Then the status bar should show the current mode
    And the mode should be either "Reading" or "Editing"

  # --- Heading Editing ---

  Scenario: Heading renders inline and becomes editable on click
    Given the document contains "# Hello World"
    Then I should see a styled heading "Hello World"
    And the markdown syntax "# " should be hidden

    When I click on the heading
    Then I should see the raw markdown "# Hello World"
    And the cursor should be positioned in the heading text
    And the transition should animate smoothly

    When I press Escape
    Then the heading should animate back to rendered state
    And the markdown syntax should be hidden again

  Scenario: Editing a heading changes its text
    Given the document contains "# Original Title"
    When I click on the heading
    And I select all text and type "# New Title"
    And I press Escape
    Then I should see a styled heading "New Title"

  # --- Bold / Italic ---

  Scenario: Bold text renders inline
    Given the document contains "This is **bold** text"
    Then "bold" should be displayed in bold style
    And the "**" markers should be hidden

    When I click on the word "bold"
    Then I should see "**bold**" with visible markers

    When I click elsewhere
    Then the "**" markers should be hidden again

  Scenario: Italic text renders inline
    Given the document contains "This is *italic* text"
    Then "italic" should be displayed in italic style
    And the "*" markers should be hidden

  Scenario: Bold italic text renders inline
    Given the document contains "This is ***bold italic*** text"
    Then "bold italic" should be displayed in bold italic style
    And the "***" markers should be hidden

  # --- Links ---

  Scenario: Links render as clickable text
    Given the document contains "[Example](https://example.com)"
    Then I should see "Example" as styled link text
    And the URL and markdown syntax should be hidden

    When I click on the link text
    Then I should see the full markdown "[Example](https://example.com)"
    And I should be able to edit both text and URL

  Scenario: Cmd+click opens link in browser
    Given the document contains "[Example](https://example.com)"
    When I Cmd+click on the rendered link
    Then the URL should open in the default browser
    And the editor should not enter edit mode for that link

  # --- Images ---

  Scenario: Images render inline
    Given the document contains "![Alt text](image.png)"
    And the file "image.png" exists relative to the document
    Then the image should be displayed inline
    And the markdown syntax should be hidden

    When I click on the image
    Then I should see the raw markdown "![Alt text](image.png)"
    And I should be able to edit the path and alt text

  Scenario: Missing image shows placeholder
    Given the document contains "![Missing](nonexistent.png)"
    And the file "nonexistent.png" does not exist
    Then a placeholder with the alt text "Missing" should be shown
    And the placeholder should indicate the image is not found

  # --- Animation ---

  Scenario: Transition animates smoothly
    Given the document contains a heading "# Test"
    When I click on the heading to enter edit mode
    Then the block height should transition smoothly over ~200ms
    And the content should fade between states
    And there should be no layout jump

  Scenario: Multiple blocks can be in edit mode
    Given the document contains:
      """
      # Heading

      A paragraph with **bold** text.
      """
    When I click on the heading to enter edit mode
    And I Cmd+click on the paragraph
    Then both blocks should be in edit mode simultaneously
    And I should be able to type in either block

  # --- General Editing ---

  Scenario: Auto-pair markdown syntax
    Given I am editing in Fluid Mode
    When I type "**"
    Then the closing "**" should be inserted automatically
    And the cursor should be between the markers

  Scenario: New content typed in Fluid Mode
    Given the document is empty
    When I type "# My New Document"
    And I press Enter twice
    And I type "First paragraph"
    And I click on the heading area
    Then the heading should be rendered as a styled heading
    And the paragraph should appear as normal text
