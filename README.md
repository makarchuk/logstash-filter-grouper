Search Elasticsearch index for records that match some field in event create new one or update existing depending on was record found or not. 
Can be used to aggregate events on some field.

I really need a better readme

Config: 
List of elasticsearch hosts to use for querying.
  ```
  config :hosts, :validate => :array
  ```

Elasticsearch query string
  ```
  config :match_field, :validate => :string
  ```

Hash of fields to copy from old event (found via elasticsearch) into new event
  ```
  config :fields, :validate => :hash, :default => {}
  ```

Basic Auth - username
  ```
  config :user, :validate => :string
  ```

Basic Auth - password
  ```
  config :password, :validate => :password
  ```

SSL
  ```
  config :ssl, :validate => :boolean, :default => false
  ```

SSL Certificate Authority file
  ```
  config :ca_file, :validate => :path
  ```

Fields to copy to new document
  ```
  config :only_fields, :validate => :array, :default => []
  ```

Fields that will be excluded from result document. Don't work if :only_fields is set
  ```
  config :exclude, :validate => :array, :default => []
  ```
  
Fields that will be stored as array in result document
  ```
  config :to_array, :validate => :array, :default => []
  ```

Hash of fields that needs to be incremented
Key -- field in result documtn 
Value -- field in event or number
  ```
  config :sum_fields, :validate => :hash, :default => {}
  ```
  
  ```
  config :inherit_fields, :validate => :array, :default => []
  ```

Add fields. Executes BEFORE filter executing
  ```
  config :add_fields, :falidate =>:hash, :default => {}
  ```

  ```
  config :remove_field, :falidate =>:array, :default => []
  ```

  ```
  config :doc_index, :validate => :string
  ```

  ```
  config :doc_type, :validate => :string
  ```