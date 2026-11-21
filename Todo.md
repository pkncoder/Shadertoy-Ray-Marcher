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

- [x] Phase 1 - Basic Workings & Definitions
	- [x] Common tab definitions
	- [x] Hello, Sphere ray marched Output
- [ ] Phase 2
	- [x] Ray Marched G-Buffer
	- [ ] More sdfs & hard-coded map function
	- [x] Skybox
	- [x] Render Pass
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
- [ ] Figure out how to stop recreating HitInfos in sdfs

### Todo - Future Todos

- [ ] Create a python program to convert my .glsl files into shadertoy compatible files
	- Get rid of \#includes
	- Add headers for file metadata and sources
	- Export into a folder & append the files
    - Use a project file for how many passes, channel definitions, and extra naming stuff

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
- Skip sampling the scene when multiple samples when there is a no-hit for the first hit

## Checklists
---

### Refactor Checklist

1. [ ] Fix placement of functions
2. [ ] Rename things
3. [ ] Change input params to have in & out
4. [ ] Add const to input params
5. [ ] Refactor step by step in code
6. [ ] Add comments
7. [ ] Place the \#includes in the right spots
8. [ ] Run `./convertToShadertoy`
