(*
 * Copyright (c) 2013-2015 OCamlPro
 * Authors Thomas Gazagnaire <thomas@gazagnaire.org>,
 *         Louis Gesbert <louis.gesbert@ocamlpro.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open OpamRTcommon
open OpamTypes
open OpamFilename.Op

let shuffle l =
  let a = Array.of_list l in
  let permute i j = let x = a.(i) in a.(i) <- a.(j); a.(j) <- x in
  for i = Array.length a - 1 downto 1 do permute i (Random.int (i+1)) done;
  Array.to_list a

let package name version contents_kind contents_root ?(gener_archive=true) seed =
  let pkg = Printf.sprintf "%s.%d" name version in
  let nv = OpamPackage.of_string pkg in
  let contents = Contents.create nv seed in
  let files_ = Packages.files seed in
  Packages.({
    nv;
    prefix   = prefix nv;
    opam     = opam nv seed;
    url      = url contents_kind (contents_root / pkg) seed;
    descr    = descr seed;
    files    = files_;
    contents;
    archive  = if gener_archive then archive (files_ @ contents) nv seed else None;
  })

let a1 contents_root =
  package "a" 1 (Some `rsync) contents_root

let a2 contents_root =
  package "a" 2 (Some `git) contents_root

let not_very_random n =
  let i = Random.int n in
  if i > Pervasives.(/) n 2 then 0 else i

let ar root _ =
  let seed = not_very_random 10 in
  if Random.int 2 = 0 then
    a1 root seed
  else
    a2 root seed

let random_list n fn =
  Array.to_list (Array.init n fn)

(* Create a repository with 2 packages and a complex history *)
let create_repo_with_history repo contents_root =
  OpamFilename.mkdir repo;
  Git.init repo;
  let repo_file =
    OpamFile.Repo.create ~opam_version:OpamVersion.current_nopatch ()
  in
  let repo_filename = OpamRepositoryPath.repo repo in
  OpamFile.Repo.write repo_filename repo_file;
  Git.commit_file repo (OpamFile.filename repo_filename) "Initialise repo";
  let all = [
    a1 contents_root 0;
    a1 contents_root 1;
    a1 contents_root 2;
    a2 contents_root 2;
    a2 contents_root 1;
    a2 contents_root 0;
  ] @ random_list 5 (ar contents_root) in
  List.iter (Packages.add repo contents_root) all;
  Git.branch repo

(* Create a repository with a single package without archive file and
   no history. *)
let create_simple_repo repo contents_root contents_kind =
  OpamFilename.mkdir repo;
  Git.init repo;
  let repo_file =
    OpamFile.Repo.create ~opam_version:OpamVersion.current_nopatch ()
  in
  let repo_filename = OpamRepositoryPath.repo repo in
  OpamFile.Repo.write repo_filename repo_file;
  Git.commit_file repo (OpamFile.filename repo_filename) "Initialise repo";
  let package0 = package "a" 1 contents_kind contents_root ~gener_archive:false 10 in
  Packages.add repo contents_root package0;
  let all =
    package0
    :: random_list 20 (fun _ ->
        package "a" 1 contents_kind contents_root ~gener_archive:false (Random.int 20)
      ) in
  List.iter (fun package ->
      Packages.write repo contents_root package
    ) all;
  Git.branch (contents_root / "a.1");
  Git.commit repo "Add package"
