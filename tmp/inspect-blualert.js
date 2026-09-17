JSON.stringify({
  placeholders: Array.from(document.querySelectorAll('flt-semantics-placeholder')).map(e => ({tag:e.tagName, rect:e.getBoundingClientRect().toJSON()})),
  inputs: Array.from(document.querySelectorAll('input,textarea')).map(e => ({tag:e.tagName,type:e.type,placeholder:e.placeholder})),
  semantics: document.querySelectorAll('flt-semantics').length
})
