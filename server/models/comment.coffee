CONFIG = require 'config'
__ = CONFIG.universalPath
error_ = __.require 'lib', 'error/error'

module.exports = Comment = {}

Comment.tests = tests = require './tests/comment'

Comment.createItemComment = (userId, message, item)->
  itemId = item._id
  tests.pass 'itemId', itemId
  createComment userId, message, 'item', itemId

Comment.createTransactionComment = (userId, message, transactionId)->
  tests.pass 'transactionId', transactionId
  createComment userId, message, 'transaction', transactionId

createComment = (userId, message, key, value)->
  tests.pass 'userId', userId
  tests.pass 'message', message

  comment =
    user: userId
    message: message
    created: Date.now()

  # the key identifies the object to which the comment is attached
  comment[key] = value

  return comment
