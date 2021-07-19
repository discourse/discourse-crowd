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

  
### Configuring Atlassian Group mappings

This part of the configuration allows users who login through discourse-crowd to automatically be added or removed from Discourse groups (at login time).
These can be configured in https://my.discourse.site/admin/site_settings/category/plugins?filter=plugin%3Adiscourse-crowd
- `crowd_groups_enabled` turns crowd mapping on or off
- `crowd_groups_mapping` is a list of colon-separated pairs. The first of each pair is an Atlassian group and the second is a comma-separated list of discourse group "slugs" (the group name in the URL). e.g. `jira-users:git_group,user_group`
- `crowd_groups_remove_unmapped_groups` when enabled means a user will be _removed_ from the discourse group(s) that are mapped to if the user is _not_ in the corresponding Atlassian group.  You probably want this on, but because it might be wrongly removing users it's off by default.
  
### License

MIT

