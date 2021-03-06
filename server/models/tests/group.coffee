{ pass, underLimitString, nonEmptyString, localImg, boolean, position } = require './common-tests'

module.exports =
  pass: pass

  # tests expected to be found on Group.tests for updates,
  # cf server/controllers/groups/lib/update_group.coffee:
  # Group.tests[attribute](value)
  name: (str)-> nonEmptyString str, 60
  picture: localImg
  description: (str)-> underLimitString str, 5000
  searchable: boolean
  position: position
