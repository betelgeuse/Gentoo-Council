Feature: Suggest Agenda Items
  As a user
  I want to be able to suggest agenda items
  so Council will consider my ideas

  Scenario: Suggest Agenda item
    Given I am logged in as example user
    And an agenda
		When I am on the home page
		And I follow "Suggest agenda item"
		And I fill in example agenda item data
		And I press "Create Agenda item"
		Then I should see "The Agenda item was created successfully" in the notices

  Scenario: Approve Agenda items
    Given example agenda item
    And an agenda
    And I am logged in as a council member
    When I am on the current agenda page
    And I follow first suggested agenda link
    And I press "Add to current agenda"
    And I should see current agenda as the agenda

  Scenario: Reject Agenda item
    Given example agenda item
    And an agenda
    And I am logged in as a council member
    When I am on the first suggested agenda page
    And I press "Reject"
    Then I should see "Rejected"

    When I press "Un-reject"
    Then I should not see "Rejected"

  Scenario: Don't list rejected agenda items
    Given rejected agenda item
    And an agenda
    When I am on the current agenda page
    Then I should not see "Rejected item"

  Scenario: When item is added to agenda don't add it to agenda and don't remove it any more
    Given agenda item in current agenda
    And I am logged in as a council member
    When I am on newest agenda item page
    Then I should not see "Add to current agenda" button
    And I should not see "Reject" button

  Scenario: Reject and Add to current agenda  buttons displayed nicely
    Given example agenda item
    And an agenda
    And I am logged in as a council member
    When I am on the first suggested agenda page
    Then I should see "Reject" button inside content body
    And "Reject" button should be inline
    And I should see "Add to current agenda" button inside content body
    And "Add to current agenda" button should be inline

  Scenario: View discussion times
    Given some agenda item with discussion times
    Then I should see discussion times when viewing agenda items

  Scenario: Show view hint on timelimits format
    Given I am logged in as a council member
    When I follow "Suggest agenda item"
    Then I should see hint on timelimits format

    Given example agenda item
    When I am on newest agenda item edit page
    Then I should see hint on timelimits format
