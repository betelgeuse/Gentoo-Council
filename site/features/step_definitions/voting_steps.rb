When /^I follow first agenda item link$/ do
  When "I follow \"#{AgendaItem.first.title}\""
end

When /^I add example voting option$/ do
  When 'I fill in "voting_option_description" with "example"'
  When 'I press "Add a voting option"'
end

Given /^example voting option$/ do
  Given 'example agenda item'
  VotingOption.new(:description => 'example', :agenda_item => AgendaItem.last).save!
end

When /^I go from the homepage to edit last voting option page$/ do
  When 'I am on the homepage'
  When 'I follow "Agendas"'
  When 'I follow link to current agenda'
  When "I follow \"#{AgendaItem.last.title}\""
  When "I follow \"#{VotingOption.last.description}\""
  When 'I follow "Edit Voting option"'
end

Given /^there is an item with some voting options for current agenda$/ do
  agenda = Factory(:agenda)
  item = Factory(:agenda_item, :agenda => agenda)
  voting_option1 = Factory(:voting_option, :agenda_item => item)
  voting_option2 = Factory(:voting_option, :agenda_item => item, :description => 'Another choice')
end

Then /^I should see my vote$/ do
  option = VotingOption.first
  Then "I should see \"#{option.description}\""
  Then "I should see \"#{option.community_votes}\""
  Then "I should see \"You voted for #{option.description}\" in the notices"
end

Given /^some community and council votes for a newer item$/ do
  agenda = Agenda.current
  item = Factory(:agenda_item, :agenda => agenda)
  option1 = Factory(:voting_option, :agenda_item => item)
  option2 = Factory(:voting_option, :agenda_item => item, :description => 'another option')
  option3 = Factory(:voting_option, :agenda_item => item, :description => 'yet another option')
  Factory(:vote, :voting_option => option1)
  Factory(:vote, :voting_option => option2)
  Factory(:vote, :voting_option => option2)
  Factory(:vote, :voting_option => option3)
  Factory(:vote, :voting_option => option3)
  Factory(:vote, :voting_option => option3)
end

Then /^I should see correct community votes$/ do
  Then 'I should see "Community votes: 1 of 6 (17%) votes. "'
  Then 'I should see "Community votes: 2 of 6 (33%) votes. "'
  Then 'I should see "Community votes: 3 of 6 (50%) votes. "'
end
