------- MODULE Example --------
CONSTANTS Person, Dog, Allergic, Furry
VARIABLES hasDog

\* tlc won't actually do this
NoDog == CHOOSE d : d \notin Dog
TypeOK == hasDog \in [Person -> Dog \union {NoDog}]
Init == hasDog = [p \in Person |-> NoDog]

NoFurWithAllergic ==
  \A p \in Person : \A d \in Dog :
    hasDog[p] # d \/ p \notin Allergic \/ d \notin Furry

Adopt(p, d) ==
  /\ p \in Person /\ d \in Dog
  /\ (p \notin Allergic \/ d \notin Furry)
  /\ hasDog' = [hasDog EXCEPT ![p] = d]
ToHeaven(p) ==
  /\ p \in Person
  /\ hasDog' = [hasDog EXCEPT ![p] = NoDog]

Sitting(p1, p2) ==
  /\ hasDog[p1] = NoDog
  /\ hasDog[p2] # NoDog
  /\ hasDog' = [[hasDog EXCEPT ![p1] = hasDog[p2]] EXCEPT ![p2] = NoDog]

Next ==
  \/ \E p \in Person : \E d \in Dog : Adopt(p, d)
  \/ \E p \in Person : ToHeaven(p)
  \/ \E p1, p2 \in Person : Sitting(p1, p2)

Spec == Init /\ [][Next]_<<hasDog>>
================================
















(*
NoFurWithAllergic ==
  \A p \in Person : \A d \in Dog :
    hasDog[p] # d \/ p \notin Allergic \/ d \notin Furry

Adopt ==
  /\ (p \notin Allergic \/ d \notin Furry)

Sitting(p1, p2) ==
  /\ hasDog[p1] = NoDog
  /\ hasDog[p2] # NoDog
  /\ hasDog' = [[hasDog EXCEPT ![p1] = hasDog[p2]] EXCEPT ![p2] = NoDog]

Next ==
  \/ \E p1, p2 \in Person : Sitting(p1, p2)
*)

