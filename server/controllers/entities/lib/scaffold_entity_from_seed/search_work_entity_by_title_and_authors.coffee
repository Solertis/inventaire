__ = require('config').universalPath
_ = __.require 'builders', 'utils'
promises_ = __.require 'lib', 'promises'
error_ = __.require 'lib', 'error/error'

searchByText = require '../../search_by_text'
getBestLangValue = __.require('sharedLibs', 'get_best_lang_value')(_)
getEntitiesByUris = require '../get_entities_by_uris'
workEntitiesCache = require './work_entity_search_dedupplicating_cache'
{ MatchTitle, MatchAuthor } = require './work_entity_search_utils'

# Search an existing work by title and authors from a seed
# to avoid creating dupplicates if a corresponding work already exists
module.exports = (seed)->
  { title, authors, lang, groupLang } = seed
  # unless a lang is explicitly passed, deduce it from the the ISBN groupLang
  lang or= groupLang

  _.log seed, 'seed'

  validAuthors = _.isArray(authors) and _.all authors, _.isNonEmptyString
  unless _.isNonEmptyString(title) and validAuthors
    _.warn seed, 'unsufficient seed data to search a pre-existing work entity'
    return promises_.resolve()

  cachedWorkPromise = workEntitiesCache.get seed
  if cachedWorkPromise? then return cachedWorkPromise

  searchByText
    search: title
    lang: lang
    # Having dataseed enable woud trigger a hell of a loop
    disableDataseed: true
  .then _.Log('results before title filter')
  # Make a first filter from the results we got
  .filter MatchTitle(title, lang)
  # Fetch the data we miss to check author match
  .map AddAuthorsStrings(lang)
  .then _.Log('results before author filter')
  # Filter the remaining results on authors
  .filter MatchAuthor(authors, lang)
  .then (matches)->
    if matches.length > 1 then _.warn matches, 'possible dupplicates'
    return matches[0]

AddAuthorsStrings = (lang)-> (result)->
  authorsUris = result.claims['wdt:P50']
  unless authorsUris?.length > 0
    _.warn result, 'no authors to add'
    result.authors = []
    return result

  getEntitiesByUris authorsUris
  .then ParseAuthorsStrings(lang)
  .then (authorsStrings)->
    result.authors = authorsStrings
    return result

ParseAuthorsStrings = (lang)-> (res)->
  _.values res.entities
  .map (authorEntity)-> getBestLangValue lang, authorEntity.originalLang, authorEntity.labels
