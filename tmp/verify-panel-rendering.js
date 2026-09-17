JSON.stringify({
  protocol:document.querySelector('section.detail code')?.textContent,
  image:Array.from(document.querySelectorAll('section.detail img')).map(image=>({complete:image.complete,naturalWidth:image.naturalWidth,naturalHeight:image.naturalHeight,rect:image.getBoundingClientRect().toJSON(),objectFit:getComputedStyle(image).objectFit,display:getComputedStyle(image).display,position:getComputedStyle(image).position})),
  queueCount:document.querySelector('.queue-title h2')?.textContent,
  live:document.querySelector('.connection')?.textContent
})
