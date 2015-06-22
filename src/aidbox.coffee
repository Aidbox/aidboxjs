URI = require('URIjs')
mod = angular.module('ngAidbox', ['ng'])

mod.service '$aidbox', ($http, $cookies, $window)->
  config = {
    client_id    : 'site'
    grant_type   : 'implicit'
    scope        : 'ups'
    redirect_uri : $window.location
  }

  box_url = null
  query = URI($window.location.search).search(true)

  loginUrl = ()->
    URI(box_url)
      .directory '/oauth/token'
      .setQuery config

  # Just return at
  access_token= ()->
    $cookies.get('ab_'+config.client_id)

  # Clear all user data
  out = ()->
    $cookies.remove 'ab_'+ config.client_id
    # Clear some other data

  @onAccessToken = (query)=>
    @user (x)->
      config.onUser(x) if config.onUser

  $window.onAccessToken = @onAccessToken

  # Init client_id  box_url and other
  @init = (param)->
    box_url = param.box
    delete param.box
    for k,v of param
      config[k] = v
    # Remove AT from uri and close modal window
    if access_token()
      console.log('access_token', access_token())
      @onAccessToken()
    if query.access_token
      $cookies.put 'ab_'+config.client_id, query.access_token
      $window.opener.onAccessToken(query)
      if $window.opener
        $window.close()

  @signin= (userCb)->
    if access_token()
      console.log 'You are signed in'
    else
      $window.open(loginUrl(), "SignIn to you Box", "width=780,height=410,toolbar=0,scrollbars=0,status=0,resizable=0,left=100,top=100")
      true

  @signout= ()->
    if access_token()
      $http.get box_url+'/signout', { params : {access_token : access_token() }}
        .success (data)->
          out()
          console.log "You are now logged out"
        .error (err)->
          out()
          console.log "Wrong access_token", err
    else
      console.log "You are not logged"

  @user = (callback)->
    $http.get box_url+'/user', { params : {access_token : access_token() }}
      .success (data)->
        callback data if callback
  @

module.exports = mod
