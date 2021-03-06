import ircmeeting.meeting as meeting
import ircmeeting.writers as writers
import re
import time
class TestMeeting:
  logline_re = re.compile(r'\[?([0-9: ]*)\]? *<[@+]?([^>]+)> *(.*)')
  loglineAction_re = re.compile(r'\[?([0-9: ]*)\]? *\* *([^ ]+) *(.*)')
  log = []

  def __init__(self):
    self.M = meeting.process_meeting(contents = '',
                                channel = "#none",  filename = '/dev/null',
                                dontSave = True, safeMode = False,
                                extraConfig = {})
    self.M._sendReply = lambda x: self.log.append(x)
    self.M.starttime = time.gmtime(0)

  def set_voters(self, voters):
    self.M.config.agenda._voters = voters

  def set_agenda(self, agenda):
    self.M.config.agenda._agenda = agenda
    self.M.config.agenda._votes = { }
    for i in agenda:
      self.M.config.agenda._votes[i[0]] = { }


  def parse_time(self, time_):
    try: return time.strptime(time_, "%H:%M:%S")
    except ValueError: pass
    try: return time.strptime(time_, "%H:%M")
    except ValueError: pass

  def process(self, content):
    for line in content.split('\n'):
      # match regular spoken lines:
      m = self.logline_re.match(line)
      if m:
        time_ = self.parse_time(m.group(1).strip())
        nick = m.group(2).strip()
        line = m.group(3).strip()
        if self.M.owner is None:
            self.M.owner = nick ; self.M.chairs = {nick:True}
        self.M.addline(nick, line, time_=time_)
      # match /me lines
      self.m = self.loglineAction_re.match(line)
      if m:
          time_ = self.parse_time(m.group(1).strip())
          nick = m.group(2).strip()
          line = m.group(3).strip()
          self.M.addline(nick, "ACTION "+line, time_=time_)

  def answer_should_match(self, line, answer_regexp):
    self.log = []
    self.process(line)
    answer = '\n'.join(self.log)
    error_msg = "Answer for:\n\t'" + line + "'\n was \n\t'" + answer +\
                "'\ndid not match regexp\n\t'" + answer_regexp + "'"
    answer_matches = re.match(answer_regexp, answer)
    assert answer_matches, error_msg

  def votes(self):
    return(self.M.config.agenda._votes)
