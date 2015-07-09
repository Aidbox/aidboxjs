URI = require('URIjs')
mod = angular.module('ngAidbox', ['ng'])

addMinutes = (d, min)->
  d && d.setMinutes(d.getMinutes() + min) && d

addSeconds = (d, x)->
  d && d.setSeconds(d.getSeconds() + x) && d

mod.service '$aidbox', ($http, $cookies, $window, $q)->
  config = {
    client_id    : 'site'
    grant_type   : 'implicit'
    scope        : 'ups'
    redirect_uri : $window.location
  }

  box_url = null
  flow = 'popup'
  query = URI($window.location.search).search(true)

  loginUrl = ()->
    URI(box_url)
      .directory '/oauth/token'
      .setQuery config

  # Just return at
  access_token= ()->
    $cookies.get('ab_'+config.client_id)

  user_state = (state, user)->
    config.onUser(state, user) if config.onUser
    switch state
      when 'signin'
        config.onSignIn(user) if config.onSignIn
      when 'signout'
        config.onSignOut() if config.onSignOut
      when 'anonimous'
        config.onAnonimous() if config.onAnonimous

  # Clear all user data
  out = ()->
    console.log('signout')
    $cookies.remove 'ab_'+ config.client_id
    user_state('signout', null)

  @onAccessToken = (query)=>
    @user (x)->
      user_state('signin', x)

  $window.onAccessToken = @onAccessToken

  # Init client_id  box_url and other
  @init = (param)->
    box_url = param.box
    flow = param.flow || 'popup' 
    delete param.box
    for k,v of param
      config[k] = v
    # Remove AT from uri and close modal window
    if access_token()
      @onAccessToken()
      return
    if query.access_token
      cookie_name = "ab_#{config.client_id}"
      expires_at = query.expires_at
      expires_at = expires_at && decodeURIComponent(expires_at)
      expires_at = (expires_at && addMinutes(new Date(expires_at), -1)) or addMinutes(new Date(), 5)
      $cookies.put(cookie_name, query.access_token, expires: expires_at)

      if flow == 'popup'
        $window.opener.onAccessToken(query)
      else
        @onAccessToken(query)
        if $window.history.replaceState
          console.log('replaceState')
          $window.history.replaceState( {}, "", $window.location.toString().replace($window.location.search, ""))

      if flow == 'pupup' && $window.opener
        $window.close()
    else
      user_state('anonimous')

  @signin= (userCb)->
    if flow == 'redirect'
      $window.location.href = loginUrl()
    else
      $window.open(loginUrl(), "SignIn to you Box", "width=780,height=410,toolbar=0,scrollbars=0,status=0,resizable=0,left=100,top=100")
      true

  http = (opts)->
    token = access_token()
    unless token
      out()
      mock =
        success: ()-> mock
        error: (cb)-> cb("session expired", 403); mock
      return mock

    opts.params ||= {}
    angular.extend(opts.params, {access_token: access_token()})
    data = opts.data && JSON.stringify(opts.data)
    args =
      url: "#{box_url}#{opts.url}"
      params: opts.params
      method: opts.method || 'GET'
      data: data
    $http(args).error  (data, st)->
      out() if st == 403

  @signout= ()->
    http(url: '/signout').success (data)-> out()

  @user = (callback)->
    http(url: '/user')
      .success (data)->
        callback data if callback

  @http = http

  @fhir =
    valueSet:
      expand: (id, filter)->
        deferred = $q.defer()
        http(
          url: "/fhir/ValueSet/#{id}/$expand"
          method: 'GET'
          params: {filter: filter}
        ).success (data)->
          deferred.resolve(data.expansion.contains)
        .error (err)->
          deferred.reject(err)

        deferred.promise

  @

module.exports = mod
