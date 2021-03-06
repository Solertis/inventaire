__ = require('config').universalPath
_ = __.require 'builders', 'utils'
db = __.require('couch', 'base')('entities')
promises_ = __.require 'lib', 'promises'
Entity = __.require 'models', 'entity'
patches_ = require './patches'
isbn_ = __.require 'lib', 'isbn/isbn'
couch_ = __.require 'lib', 'couch'
validateClaimValue = require('./validate_claim_value')(db)
getInvEntityCanonicalUri = require './get_inv_entity_canonical_uri'

{ properties, validateProperty } = require './properties'

module.exports = entities_ =
  db: db
  byId: db.get

  byIds: (ids)->
    ids = _.forceArray ids
    db.fetch ids
    .then _.compact

  byIsbns: (isbns)->
    keys = isbns
      .map (isbn)-> isbn_.toIsbn13 isbn, true
      .filter _.identity
      .map (isbn)-> ['wdt:P212', isbn]
    db.viewByKeys 'byClaim', keys

  byIsbn: (isbn)->
    entities_.byIsbns [ isbn ]
    .then couch_.firstDoc

  byWikidataIds: (ids)->
    keys = ids.map (id)-> ['invp:P1', id]
    db.viewByKeys 'byClaim', keys

  byClaim: (property, value, includeDocs=false)->
    promises_.try -> validateProperty property
    .then ->
      db.view 'entities', 'byClaim',
        key: [ property, value ]
        include_docs: includeDocs

  idsByClaim: (property, value)->
    entities_.byClaim property, value
    .then couch_.mapId

  byClaimsValue: (value)->
    db.view 'entities', 'byClaimValue',
      key: value
      include_docs: false
    .then (res)->
      res.rows.map (row)->
        entity: row.id
        property: row.value

  create: ->
    # Create a new entity doc.
    # This constituts the basis on which next modifications patch
    db.postAndReturn Entity.create()
    .then _.Log('created doc')

  edit: (userId, updatedLabels, updatedClaims, currentDoc)->
    updatedDoc = _.cloneDeep currentDoc
    promises_.try ->
      updatedDoc = Entity.setLabels updatedDoc, updatedLabels
      return Entity.addClaims updatedDoc, updatedClaims

    .then entities_.putUpdate.bind(null, userId, currentDoc)

  updateLabel: (lang, value, userId, currentDoc)->
    updatedDoc = _.cloneDeep currentDoc
    updatedDoc = Entity.setLabel updatedDoc, lang, value
    return entities_.putUpdate userId, currentDoc, updatedDoc

  updateClaim: (params)->
    { property, oldVal, userId, currentDoc } = params
    updatedDoc = _.cloneDeep currentDoc
    params.currentClaims = currentDoc.claims
    params.letEmptyValuePass = true
    entities_.validateClaim params
    .then (formattedValue)->
      Entity.updateClaim updatedDoc, property, oldVal, formattedValue
    .then entities_.putUpdate.bind(null, userId, currentDoc)

  validateClaim: (params)->
    { property } = params
    promises_.try -> validateProperty property
    .then -> validateClaimValue params

  # Assumes that the property is valid
  validatePropertyValueSync: (property, value)-> properties[property].test value

  getLastChangedEntitiesUris: (since, limit)->
    db.changes
      filter: 'entities/entities'
      limit: limit
      since: since
      include_docs: true
      descending: true
    .then (res)->
      # TODO: return URIs in no-redirect mode so that redirections appear in entity changes
      uris: res.results.map parseCanonicalUri
      lastSeq: res.last_seq

  putUpdate: (userId, currentDoc, updatedDoc)->
    _.log currentDoc, 'current doc'
    _.log updatedDoc, 'updated doc'
    _.types arguments, ['string', 'object', 'object']
    db.putAndReturn updatedDoc
    .tap -> patches_.create userId, currentDoc, updatedDoc

parseCanonicalUri = (result)-> getInvEntityCanonicalUri(result.doc)[0]
