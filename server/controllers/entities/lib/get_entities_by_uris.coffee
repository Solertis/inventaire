__ = require('config').universalPath
_ = __.require 'builders', 'utils'
error_ = __.require 'lib', 'error/error'
promises_ = __.require 'lib', 'promises'
wdk = require 'wikidata-sdk'
{ normalizeIsbn, isNormalizedIsbn } = __.require 'lib', 'isbn/isbn'

# Getters take ids, return an object on the model { entities, notFound }
getters =
  inv: require './get_inv_entities'
  wd: require './get_wikidata_enriched_entities'
  isbn: require './get_entities_by_isbns'

prefixes = Object.keys getters

module.exports = (uris, refresh)->
  domains =
    wd: []
    inv: []
    isbn: []

  # validate per URI to be able to return a precise error message
  for uri in uris
    [ prefix, id ] = uri.split ':'

    unless prefix in prefixes
      errMessage = "invalid uri prefix: #{prefix} (uri: #{uri})"
      return error_.reject errMessage, 400, uri

    unless validators[prefix](id)
      errMessage = "invalid uri id: #{id} (uri: #{uri})"
      return error_.reject errMessage, 400, uri

    if prefix in hasFormatter then id = formatters[prefix](id)
    domains[prefix].push id

  getDomainsPromises domains, refresh
  .then mergeResponses
  .catch _.ErrorRethrow("getEntitiesByUris err: #{uris.join('|')}")

getDomainsPromises = (domains, refresh)->
  promises = []
  for prefix, array of domains
    if array.length > 0
      promises.push getters[prefix](array, refresh)

  return promises_.all promises

mergeResponses = (results)->
  response =
    # entities are a array until they are indexed by uri hereafter
    entities: []
    # collect redirections at the response root to let the possibility
    # to the client to alias entities
    redirects: {}
    notFound: []

  for result in results
    _.type result.entities, 'array'
    for entity in result.entities
      if entity.redirects?
        { from, to } = entity.redirects
        _.types [from, to], 'strings...'
        response.redirects[from] = to
        delete entity.redirects

    # concat all entities
    response.entities = response.entities.concat result.entities

    # concat the list of not found URIs
    if result.notFound?
      response.notFound = response.notFound.concat result.notFound

  response.entities = _.indexBy response.entities, 'uri'

  if response.notFound.length is 0 then delete response.notFound

  return response

formatters =
  isbn: normalizeIsbn

hasFormatter = Object.keys formatters

validators =
  inv: _.isInvEntityId
  wd: wdk.isWikidataEntityId
  isbn: isNormalizedIsbn
