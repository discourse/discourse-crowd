### discourse-crowd

A Discourse Plugin to enable authentication via Atlassian Crowd.


### Configuration For Docker Installations Of Crowd

Add the following to the 'env' section of your container/<app>.yml


`  #Support For Crowd Plugin`  
`  #Mode should be either 'separated' or 'mixed'`  
`  DISCOURSE_CROWD_SERVER_URL: <SERVER URL>`  
`  DISCOURSE_CROWD_APPLICATION_NAME: <USER_NAME>`  
`  DISCOURSE_CROWD_APPLICATION_PASSWORD: <PASSWORD>`  
`  DISCOURSE_CROWD_APPLICATION_MODE: <MODE>`  



### Configuration For Non Docker Installations

Add the following settings to your `discourse.conf` file:

- `crowd_server_url`
- `crowd_application_name`
- `crowd_application_password`
- `crowd_application_mode` - can be one of `separated` or `mixed`

### License

MIT

