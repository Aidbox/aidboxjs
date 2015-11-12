URI = require('URIjs')

#this is hack to handle location 
#before angular does
onload = ()->
  query = URI(window.location.search).search(true)
  window.aidbox = {query: query}
  if window.history.replaceState
    window.history.replaceState({}, "", window.location.toString().replace(window.location.search, ""))
onload()

addMinutes = (d, min)->
  d && d.setMinutes(d.getMinutes() + min) && d

addSeconds = (d, x)->
  d && d.setSeconds(d.getSeconds() + x) && d

merge = (targ, from)->
  for k,v of from
    targ[k] = v
  targ

OAUTH_KEYS = [
  'client_id'
  'grant_type'
  'scope'
  'redirect_uri'
  'lang'
]

loginUrl = (config)->
  opts = {}
  for k,v of config
    opts[k] = v if OAUTH_KEYS.indexOf(k) > -1
  URI(config.box).directory('/oauth/token').setQuery(opts)

store_access_token = ($cookies, config, query)->
  cookie_name = "ab_#{config.client_id}"
  expires_at = query.expires_at
  expires_at = expires_at && decodeURIComponent(expires_at)
  expires_at = (expires_at && addMinutes(new Date(expires_at), -1)) or addMinutes(new Date(), 5)
  $cookies.put(cookie_name, query.access_token, expires: expires_at)
  $cookies.put('refresh_token', query.refresh_token)


drop_access_token = ($cookies, config)->
  $cookies.remove 'ab_'+ config.client_id
drop_refresh_token = ($cookies, config)->
  $cookies.remove 'refresh_token'

decode_query = (query)->
  res = {}
  for k,v of query
    res[k] = decodeURIComponent(v)
  res

mk_signin= ($window, config)->
  ()->
    if config.flow == 'redirect'
      $window.location.href = loginUrl(config)
    else
      window_opts = "width=780,height=410,toolbar=0,scrollbars=0,status=0,resizable=0,left=100,top=100"
      $window.open(loginUrl(config), "SignIn to you Box", window_opts)
      true

mk_http =($http, config, access_token, out, $q, $window)->
  (opts)->
    deferred = $q.defer()
    opts.params ||= {}
    access_token().then (token)->
      opts.params.access_token = token if token
      data = opts.data && angular.toJson(opts.data)
      args =
        url: "#{config.box}#{opts.url}"
        params: opts.params
        method: opts.method || 'GET'
        data: data
      $http(args)
        .success (data)->
          deferred.resolve data
        .error (err, st)->
          if st == 403
            out()
            $window.location.href = loginUrl(config)
          else
            deferred.reject(err)
      deferred.promise

mk_fhir = (http, $q)->
  valueSet:
    expand: (id, filter)->
      deferred = $q.defer()
      http(
        url: "/fhir/ValueSet/#{id}/$expand"
        method: 'GET'
        params: {filter: filter}
      ).then( ((data)-> deferred.resolve(data.expansion.contains)) , ((err)-> deferred.reject(err)))

      deferred.promise

user_state = (config, state, user)->
  config.onUser(state, user) if config.onUser
  switch state
    when 'signin'
      config.onSignIn(user) if config.onSignIn
    when 'signout'
      config.onSignOut() if config.onSignOut
    when 'anonymous'
      config.onAnonymous() if config.onAnonymous

callHandler = ($window, config, obj, cb, args...)=>
  if config.flow == 'popup' && $window.opener
    obj = $window.opener
  obj[cb].apply(obj, args)
  if config.flow == 'popup' && $window.opener
    $window.close()
  return

mod = angular.module('ngAidbox', ['ng'])
mod.service '$aidbox', ($http, $cookies, $window, $q)->
  config = {
    flow: 'popup'
    client_id    : 'site'
    box: null
    grant_type   : 'implicit'
    scope        : '*'
    redirect_uri : $window.location
  }

  update_access_token = (rt, config)->
    deferred = $q.defer()
    $http(
        url: "#{config.box}/oauth/refresh"
        method: 'POST'
        params: {refresh_token: rt}
      ).success (data)->
        deferred.resolve(data)
      .error (err)->
        deferred.reject(err)
    deferred.promise

  read_access_token = (config)->
    deferred = $q.defer()
    at = $cookies.get('ab_'+config.client_id)
    rt = $cookies.get('refresh_token')
    if (!at && rt)
      update_access_token(rt, config).then (query)->
        store_access_token($cookies, config, query)
        deferred.resolve(query.access_token)
    else if (!at && !rt)
      deferred.resolve(null)

    deferred.resolve(at) if at
    deferred.promise

  access_token= -> read_access_token(config)

  out = ->
    drop_access_token($cookies, config)
    drop_refresh_token($cookies, config)
    user_state(config, 'signout', null)

  @onError = (query)=>
    config.onError(decode_query(query)) if config.onError

  $window.onError = @onError

  @onSession = ()->
    @user (x)->
      user_state(config, 'signin', x)

  @onAccessToken = (query)=>
    store_access_token($cookies, config, query)
    @onSession()

  $window.onAccessToken = @onAccessToken

  @init = (param)->
    config = merge(config, param)
    query = $window.aidbox && $window.aidbox.query || {}
    if query.error
      callHandler($window, config, this, 'onError', query)
    else if query.access_token
      callHandler($window, config, this, 'onAccessToken', query)

    self = @
    access_token().then (at)->
      if at
        self.onSession()
      else
        user_state(config, 'anonymous')
        return

  http = mk_http($http, config, access_token, out, $q,$window)
  @loginUrl = loginUrl
  @http = http
  @signin = mk_signin($window, config)
  @signout= -> http(url: '/signout').then ()-> out()
  @user = (cb)-> http(url: '/user').then (data)-> cb && cb(data)
  @fhir = mk_fhir(http, $q)
  @

module.exports = mod
