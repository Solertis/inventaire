__ = require('config').universalPath
_ = __.require 'builders', 'utils'
error_ = __.require 'lib', 'error/error'
getEntitiesByUris = require './lib/get_entities_by_uris'
{ merge:mergeEntities, turnIntoRedirection } = require './lib/merge_entities'

# Assumptions:
# - ISBN are already desambiguated and should thus never need merge
#   out of the case of merging with an existing Wikidata edition entity
#   but those are ignored for the moment: not enough of them, data mixed with works, etc.
# - The merged entity data may be lost: the entity was probably a placeholder
#   what matter is the redirection. Or more fine, reconciling strategy can be developed later

# Only inv entities can be merged yet
validFromPrefix = [ 'inv' ]
validToPrefix = [ 'wd', 'inv' ]

# Only books and authors can be merged yet
validTypes = [ 'work', 'human' ]

module.exports = (req, res)->
  { body } = req
  { from:fromUri, to:toUri } = body
  { _id:userId } = req.user

  # Not using _.isEntityUri, letting the logic hereafter check specific prefixes
  unless _.isNonEmptyString fromUri
    return error_.bundle req, res, "missing parameter: from", 400, body

  unless _.isNonEmptyString toUri
    return error_.bundle req, res, "missing parameter: to", 400, body

  [ fromPrefix, fromId ] = fromUri.split ':'
  [ toPrefix, toId ] = toUri.split ':'

  unless fromPrefix in validFromPrefix
    return error_.bundle req, res, "invalid 'from' uri domain: #{fromPrefix}. Accepted domains: #{validFromPrefix}", 400, body

  unless toPrefix in validToPrefix
    return error_.bundle req, res, "invalid 'to' uri domain: #{toPrefix}. Accepted domains: #{validToPrefix}", 400, body

  _.log { merge: body, user: userId }, 'entity merge request'

  # Let getEntitiesByUris test for the whole URI validity
  # Get data from concerned entities
  getEntitiesByUris [ fromUri, toUri ], true
  .get 'entities'
  .then Merge(userId, toPrefix, fromUri, toUri)
  .then _.Ok(res)
  .catch error_.Handler(req, res)

Merge = (userId, toPrefix, fromUri, toUri)-> (entitiesByUri)->
  fromEntity = entitiesByUri[fromUri]
  unless fromEntity? then throw notFound 'from', fromUri

  toEntity = entitiesByUri[toUri]
  unless toEntity? then throw notFound 'to', toUri

  unless fromEntity.type is toEntity.type
    # Exception: authors can be organizations and collectives of all kinds
    # which will not get a 'human' type
    unless fromEntity.type is 'human' and not toEntity.type?
      throw error_.new "type don't match: #{fromEntity.type} / #{toEntity.type}", 400, fromUri, toUri

  unless fromEntity.type in validTypes
    throw error_.new "this type can't be merged: #{fromEntity.type} (only #{validTypes})", 400, fromUri, toUri

  [ fromPrefix, fromId ] = fromUri.split ':'
  [ toPrefix, toId ] = toUri.split ':'

  if toPrefix is 'inv'
    return mergeEntities userId, fromId, toId
  else
    # no merge to do for Wikidata entities, simply creating a redirection
    return turnIntoRedirection userId, fromId, toUri

notFound = (label, context)->
  error_.new "'#{label}' entity not found (could it be not it's canonical uri?)", 400, context
