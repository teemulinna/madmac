Feature: Reading Mode
  As a user viewing a markdown document
  I want to see beautifully rendered content
  So that I can read documents without seeing raw markdown syntax

  Background:
    Given macmd is running
    And a markdown file is open in Reading Mode

  Scenario: Headings render with proper hierarchy
    Given the document contains:
      """
      # Heading 1
      ## Heading 2
      ### Heading 3
      #### Heading 4
      """
    Then I should see 4 headings with decreasing font sizes
    And each heading should have appropriate spacing
    And no "#" characters should be visible

  Scenario: Inline formatting renders correctly
    Given the document contains:
      """
      This is **bold**, *italic*, ***bold italic***, and ~~strikethrough~~ text.
      This has `inline code` and a [link](https://example.com).
      """
    Then "bold" should be displayed in bold
    And "italic" should be displayed in italic
    And "bold italic" should be displayed in bold italic
    And "strikethrough" should have a line through it
    And "inline code" should have a code background
    And "link" should be displayed as a clickable link
    And no markdown syntax characters should be visible

  Scenario: Code blocks render with syntax highlighting
    Given the document contains:
      """
      ```python
      def hello():
          print("Hello, World!")
      ```
      """
    Then I should see a code block with a distinct background
    And the code should have syntax coloring for Python
    And the language label "python" should be visible

  Scenario: Code blocks without language specified
    Given the document contains:
      """
      ```
      plain text code block
      ```
      """
    Then I should see a code block with a distinct background
    And the text should be displayed in monospace font
    And no syntax highlighting should be applied

  Scenario: Lists render correctly
    Given the document contains:
      """
      - Item one
      - Item two
        - Nested item
      - Item three

      1. First
      2. Second
      3. Third
      """
    Then I should see an unordered list with 3 items and 1 nested item
    And I should see an ordered list with items numbered 1-3
    And bullet points and numbers should be properly styled

  Scenario: Task lists render with checkboxes
    Given the document contains:
      """
      - [ ] Unchecked task
      - [x] Completed task
      - [ ] Another task
      """
    Then I should see 3 items with checkbox indicators
    And the second item should appear checked/completed
    And the other items should appear unchecked

  Scenario: Tables render as formatted tables
    Given the document contains:
      """
      | Name  | Age | City     |
      |-------|-----|----------|
      | Alice | 30  | Helsinki |
      | Bob   | 25  | Espoo    |
      """
    Then I should see a formatted table with headers and 2 data rows
    And the table should have visible borders or grid lines
    And column alignment should be respected

  Scenario: Images render inline
    Given the document contains an image reference to an existing file
    When the image file exists at the referenced path
    Then the image should render inline at appropriate size
    And the alt text should be available for accessibility

  Scenario: Blockquotes render with visual indicator
    Given the document contains:
      """
      > This is a quote
      > spanning multiple lines
      >
      > With a paragraph break
      """
    Then the quote should have a left border or indent indicator
    And the text should be visually distinct from body text

  Scenario: Horizontal rules render
    Given the document contains:
      """
      Above the rule

      ---

      Below the rule
      """
    Then a horizontal line should be visible between the paragraphs

  Scenario: Links are clickable in Reading Mode
    Given the document contains "[Example](https://example.com)"
    When I click on the rendered link "Example"
    Then the link should open in the default browser

  Scenario: Front matter is hidden in Reading Mode
    Given the document contains:
      """
      ---
      title: My Document
      date: 2026-04-03
      ---

      # Actual Content
      """
    Then the YAML front matter should not be visible
    And only "Actual Content" heading and below should be displayed

  Scenario: Footnotes render correctly
    Given the document contains:
      """
      This has a footnote[^1].

      [^1]: This is the footnote content.
      """
    Then the footnote reference should be a superscript link
    And the footnote content should appear at the bottom of the document
