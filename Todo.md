# Todo.md

This file contains information to store for this project, including:
- Todos
- Development Phases & Status
- Checklists for use during development

## Table of Contents
---
<!--toc:start-->
- [[#Development Phases]]
- [[#Todos]]
  - [[#Todo - Code]]
  - [[#Todo - Not Code]]
  - [[#Todo - Future Todos]]
  - [[#Todo - Editor]]
  - [[#Finished Todos]]
- [[#Ideas]]
- [[#Checklists]]
  - [[#Refactor Checklist]]
<!--toc:end-->

## Development Phases
---

- [ ] Phase 1 - Basic Workings & Definitions
	- [ ] Common tab definitions
	- [ ] Hello, Sphere ray marched Output
- [ ] Phase 2
	- [ ] Ray Marched G-Buffer
	- [ ] More sdfs & hard-coded map function
	- [ ] Skybox
	- [ ] Render Pass
- [ ] Phase 3
	- [ ] Cone Marching
	- [ ] Scene definition though macros
	- [ ] Basic operations
- [ ] Phase 4
	- [ ] Full operation list minus space-warping ones
- [ ] Phase 5
	- [ ] Full implementation of list including space - warping
	- [ ] Analytical gradient curves

## Todos
---

### Todo - Code

### Todo - Not Code

- [ ] Figure out how materials will work to distinguish them
- [ ] Figure out how computing the BDRF will work

### Todo - Future Todos

- [ ] Create a python program to convert my .glsl files into shadertoy compatible files
	- Get rid of \#includes
	- Add headers for file metadata and sources
	- Export into a folder & append the files

### Todo - Editor

- [ ] Get rid of marksman errors
	- [ ] error MD022/blanks-around-headings
	- [ ] error MD013/line-length
    - [ ] error MD007/ul-indent

### Finished Todos

## Ideas
---

- Analytical Gradients for ray marching normals
- Adding fBM support for texturing materials
- Adding fBM support for bump mapping & normals

## Checklists
---

### Refactor Checklist

1. [ ] Fix warnings
2. [ ] Fix placement of functions
3. [ ] Refactor step by step in code
4. [ ] Rename things
5. [ ] Add comments
6. [ ] Place the \#includes in the right spots
7. [ ] Run `./convertToShadertoy`
