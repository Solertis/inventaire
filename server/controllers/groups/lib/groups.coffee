CONFIG = require 'config'
__ = CONFIG.universalPath
_ = __.require 'builders', 'utils'
promises_ = __.require 'lib', 'promises'
error_ = __.require 'lib', 'error/error'
Group = __.require 'models', 'group'

db = __.require('couch', 'base')('users', 'groups')

module.exports = groups_ =
  # using a view to avoid returning users or relations
  byId: db.viewFindOneByKey.bind(db, 'byId')
  byUser: db.viewByKey.bind(db, 'byUser')
  byInvitedUser: db.viewByKey.bind(db, 'byInvitedUser')
  byAdmin: (userId)->
    # could be simplified by making the byUser view
    # emit an arrey key with the role as second parameter
    # but it would make groups_.byUser more complex
    # (i.e. use a range instead of a simple key)
    db.viewByKey 'byUser', userId
    .filter Group.userIsAdmin.bind(null, userId)

  # /!\ the 'byName' view does return groups with 'searchable' set to false
  nameStartBy: (name, limit=10)->
    name = name.toLowerCase()
    db.viewCustom 'byName',
      startkey: name
      endkey: name + 'Z'
      include_docs: true
      limit: limit

  # including invitations
  allUserGroups: (userId)->
    promises_.all [
      groups_.byUser(userId)
      groups_.byInvitedUser(userId)
    ]
    .spread _.union.bind(_)

  create: (options)->
    promises_.try -> Group.create options
    .then _.Log('group created')
    .then db.postAndReturn

  findUserGroupsCoMembers: (userId)->
    groups_.byUser userId
    .then groups_.allGroupsMembers
    .then _.uniq
    # .then _.Log('allGroupsMembers')

  userInvited: (userId, groupId)->
    groups_.byId groupId
    .then _.partial(Group.findInvitation, userId, _, true)

  byCreation: (limit=10)->
    db.viewCustom 'byCreation',
      limit: limit
      descending: true
      include_docs: true

groups_.byPosition = __.require('lib', 'by_position')(db, 'groups')

membershipActions = require('./membership_actions')(db)
usersLists = require('./users_lists')(groups_)
updateGroup = require('./update_group')(db)
counts = require('./counts')(groups_, _)
leaveGroups = require('./leave_groups')(db, groups_)

_.extend groups_, membershipActions, usersLists, updateGroup, counts, leaveGroups

# getGroupPublicData depends on user_ which depends on groups_.
# Initializing at next tick allows to work around this dependency loop
# /!\ getGroupPublicData will be undefined until lateInit runs:
# avoid `{ getGroupPublicData } = groups_`
# prefer keeping a reference to groups_: `groups_.getGroupPublicData`
process.nextTick ->
  groups_.getGroupPublicData = require('./group_public_data')(groups_)
