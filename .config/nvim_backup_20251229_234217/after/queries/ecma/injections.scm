;extends

; CSS highlighting for styled-components template literals
(call_expression
  function: (identifier) @_name
  arguments: (template_string) @injection.content
  (#match? @_name "^(styled|css)$")
  (#set! injection.language "css")
  (#set! injection.include-children))

; CSS highlighting for member expressions (styled.div``)
(call_expression
  function: (member_expression
    object: (identifier) @_object
    property: (property_identifier))
  arguments: (template_string) @injection.content
  (#eq? @_object "styled")
  (#set! injection.language "css")
  (#set! injection.include-children))

; CSS highlighting for tagged templates - more conservative approach
(tagged_template_expression
  tag: (identifier) @_tag
  template: (template_string) @injection.content
  (#any-of? @_tag "css" "styled")
  (#set! injection.language "css")
  (#set! injection.include-children))