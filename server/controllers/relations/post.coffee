__ = require('config').universalPath
_ = __.require 'builders', 'utils'
user_ = __.require 'lib', 'user/user'
intent = require './lib/intent'
error_ = __.require 'lib', 'error/error'
tests = __.require 'models', 'tests/common-tests'
promises_ = __.require 'lib', 'promises'
{ Track } = __.require 'lib', 'track'

module.exports = (req, res, next) ->
  { user, action } = req.body

  unless _.isString(action) and action in possibleActions
    return error_.bundle req, res, 'bad actions parameter', 400, req.body
  unless tests.userId user
    return error_.bundle req, res, 'bad user parameter', 400, req.body

  userId = req.user._id

  promises_.try -> solveNewRelation action, user, userId
  .then _.success.bind(null, user, "#{action}: OK!")
  .then _.Ok(res)
  .then Track(req, ['relation', action])
  .catch error_.Handler(req, res)

solveNewRelation = (action, othersId, userId)->
  if userId is othersId
    throw error_.new 'cant create relation between identical ids', 400, arguments

  type = actions[action]
  return method type, userId, othersId

method = (type, userId, othersId)->
  intent[type](userId, othersId)

actions =
  request: 'requestFriend'
  cancel: 'cancelFriendRequest'
  accept: 'acceptRequest'
  discard: 'discardRequest'
  unfriend: 'removeFriendship'

possibleActions = Object.keys actions