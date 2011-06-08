require 'spec_helper'

describe Agenda do
  it 'shouldn not allow anyone to create' do
    a = Agenda.new
    for u in users_factory(AllRoles)
      a.should_not be_creatable_by(u)
      a.should_not be_destroyable_by(u)
    end
  end

  it 'shouldn not allow anyone to destory' do
    a = Factory(:agenda)
    for u in users_factory(AllRoles)
      a.should_not be_destroyable_by(u)
    end
  end

  it 'should allow everybody to view' do
    a = Factory(:agenda)
    for u in users_factory(AllRoles)
      a.should be_viewable_by(u)
    end
  end

  it 'should allow only administrators and council members to edit and update' do
    a = Factory(:agenda)
    for u in users_factory(:guest, :user)
      a.should_not be_editable_by(u)
      a.should_not be_updatable_by(u)
    end
  end

  def test_migration(object, migration, prohibited, allowed, final_state)
    # object - object to migrate
    # migration - migration name
    # prohibited - array of users who can not perform migration
    # allowed - *one* user who can perform migration
    # final_state - state of object after migration
    for user in prohibited
      lambda { object.lifecycle.send("#{migration}!", user) }.should raise_error
    end

    object.lifecycle.send("#{migration}!", allowed)
    object.state.should == final_state
  end

  it 'should have working transitions, available only to council members and administrators' do
    Factory(:agenda)
    prohibited = users_factory(:guest, :user)
    allowed = users_factory(:council, :admin, :council_admin)

    for user in allowed
      agenda = Agenda.last
      test_migration(agenda, :close, prohibited, user, 'submissions_closed')
      test_migration(agenda, :reopen, prohibited, user, 'open')
      test_migration(agenda, :close, prohibited, user, 'submissions_closed')
      test_migration(agenda, :archive, prohibited, user, 'old')
    end

  end

  it 'that is non-archival should not be valid if there other open agenda' do
    a = Factory(:agenda)
    Agenda.new.should_not be_valid
    Agenda.new(:state => 'submissions_closed').should_not be_valid
  end

  it 'that is non-archival should not be valid if there other closed agenda' do
    a = Factory(:agenda, :state => 'submissions_closed')
    Agenda.new.should_not be_valid
    Agenda.new(:state => 'submissions_closed').should_not be_valid
  end

  it 'that is archival should be valid' do
    a = Factory(:agenda, :state => 'old')
    a.should be_valid
  end

  it 'should create new open agenda, when current agenda is archived' do
    a = Factory(:agenda)
    u = users_factory(:admin)
    a.lifecycle.close! u
    a.lifecycle.archive! u
    Agenda.last.state.should == 'open'
  end

  it 'should set meeting time to now by default' do
    a1 = Factory(:agenda)
    a2 = Factory(:agenda, :meeting_time => 2.days.ago, :state => 'old')
    today = Time.now.strftime('%Y-%m-%d')

    a1.meeting_time.strftime('%Y-%m-%d').should == today
    a2.meeting_time.strftime('%Y-%m-%d').should_not == today
  end

  it 'should not create  add all council members and only them as participants when archived' do
    users_factory(:user, :admin)
    users_factory(:council, :council)
    agenda = Factory(:agenda, :state => 'submissions_closed')
    agenda.lifecycle.archive!(User.council_member_is(true).first)

    agenda.participations.should be_empty
  end
  it 'should properly create votes' do
    Factory(:agenda)
    a1 = Factory(:agenda_item, :agenda => Agenda.current)
    a2 = Factory(:agenda_item, :agenda => Agenda.current)
    a3 = Factory(:agenda_item, :agenda => Agenda.current)
    Agenda.current.agenda_items.each do |item|
      Factory(:voting_option, :agenda_item => item, :description => 'Yes')
      Factory(:voting_option, :agenda_item => item, :description => 'No')
      Factory(:voting_option, :agenda_item => item, :description => 'Dunno')
    end

    u = users_factory(:council, :council, :council)
    Vote.count.should be_zero

    results_hash = {
        a1.title => { u[0].irc_nick => 'Yes', u[1].irc_nick => 'Yes', u[2].irc_nick => 'Yes'},
        a2.title => { u[0].irc_nick => 'Yes', u[1].irc_nick => 'No', u[2].irc_nick => 'Dunno'},
        a3.title => { u[0].irc_nick => 'Dunno', u[1].irc_nick => 'Dunno', u[2].irc_nick => 'No'}
    }

    Agenda.process_results results_hash

    Vote.count.should be_equal(9)

    u[0].votes.*.voting_option.*.description.should == ['Yes', 'Yes', 'Dunno']
    u[1].votes.*.voting_option.*.description.should == ['Yes', 'No', 'Dunno']
    u[2].votes.*.voting_option.*.description.should == ['Yes', 'Dunno', 'No']
    a1.voting_options.*.votes.flatten.*.voting_option.*.description.should == ['Yes', 'Yes', 'Yes']
    a2.voting_options.*.votes.flatten.*.voting_option.*.description.should == ['Yes', 'No', 'Dunno']
    a3.voting_options.*.votes.flatten.*.voting_option.*.description.should == ['No', 'Dunno', 'Dunno']
  end

  it 'should return proper voters' do
    users = users_factory([:council]*3 + [:user])
    proxy = Factory(:proxy, :council_member => users.first, :proxy => users.last)
    voters = Agenda.voters

    voters.length.should be_equal(3)
    nicks = users.*.irc_nick - [users.first.irc_nick]
    voters.length.should be_equal(nicks.length)
    (voters - nicks).should be_empty
    (nicks - voters).should be_empty
  end

  it 'should add Agenda.send_current_agenda_reminders to delayed jobs when created' do
    Agenda.should_receive_delayed(:send_current_agenda_reminders)
    Factory(:agenda)
  end

  it 'should add Agenda.send_current_agenda_reminders to delayed jobs when meeting time changes' do
    a = Factory(:agenda)
    Agenda.should_receive_delayed(:send_current_agenda_reminders)
    a.meeting_time = Time.now + 24.hours
    a.save!
  end

  it 'should set email_reminder_sent to false when time changes' do
    a = Factory(:agenda, :email_reminder_sent => true)
    lambda {
    a.meeting_time = Time.now + 24.hours
    a.save!
    }.should change(a, :email_reminder_sent?).from(true).to(false)
  end

  it 'should send reminders properly with send_current_agenda_reminders using delayed jobs' do
    agenda = Factory(:agenda)
    users = users_factory([:user] * 2)
    council = users_factory([:council] * 2)
    Factory(:proxy, :proxy => users.first, :council_member => council.first, :agenda => agenda)
    UserMailer.should_receive_delayed(:deliver_meeting_reminder, council.last, agenda)
    UserMailer.should_receive_delayed(:deliver_meeting_reminder, users.first, agenda)

    Agenda.send_current_agenda_reminders

    agenda.reload
    agenda.email_reminder_sent.should be_true
  end

  it 'should not send reminders with send_current_agenda_reminders if Agenda.current.email_reminder_sent is true' do
    a = Factory(:agenda, :email_reminder_sent => true)
    users = users_factory([:user] * 2)
    UserMailer.should_not_receive(:delay)
    Agenda.send_current_agenda_reminders
  end

  it 'should return proper irc_reminders hash' do
    CustomConfig['Reminders']["hours_befeore_meeting_to_send_irc_reminders"] = 2

    a1 = Factory(:agenda)
    users = users_factory([:council]*2 + [:user]*2)
    Agenda.irc_reminders.keys.should include('remind_time')
    Agenda.irc_reminders.keys.should include('message')
    Agenda.irc_reminders.keys.should include('users')

    Agenda.irc_reminders['remind_time'].should == Agenda.current.meeting_time.strftime('%a %b %d %H:%M:%S %Y')
    Agenda.irc_reminders['users'].should == Agenda.voters

    a1.meeting_time = 10.years.from_now
    a1.save!

    Agenda.irc_reminders.should be_empty
  end
end
