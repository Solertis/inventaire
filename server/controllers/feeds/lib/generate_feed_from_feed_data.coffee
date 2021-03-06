CONFIG = require 'config'
__ = require('config').universalPath
_ = __.require 'builders', 'utils'
{ feed:feedConfig } = CONFIG
items_ = __.require 'controllers', 'items/lib/items'
serializeFeed = require './serialize_feed'

module.exports = (lang)-> (feedData)->
  { users, semiPrivateAccessRight, feedOptions } = feedData
  usersIds = users.map _.property('_id')
  getLastItemsFromUsersIds usersIds, semiPrivateAccessRight
  .then (items)-> serializeFeed feedOptions, users, items, lang

getLastItemsFromUsersIds = (usersIds, semiPrivateAccessRight)->
  fnName = if semiPrivateAccessRight then 'friendsListings' else 'publicListings'
  items_[fnName](usersIds)
  .then extractLastItems

extractLastItems = (items)->
  items
  .sort (a, b)-> b.created - a.created
  .slice 0, feedConfig.limitLength
