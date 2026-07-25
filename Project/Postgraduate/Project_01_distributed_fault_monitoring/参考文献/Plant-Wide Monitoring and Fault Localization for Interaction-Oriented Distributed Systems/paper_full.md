# Plant-Wide Monitoring and Fault Localization for Interaction-Oriented Distributed Systems

Abstract—In order to improve the management capability and control degree of the large-scale industrial systems, physically distributed plants and sub-processes are connected through various types of networks. This introduces serious safety and security hazards to the plant-wide process. It is practically demanded to develop effective plant-wide monitoring schemes and secure data transmission techniques. To this end, this paper proposes a novel data-driven approach to monitor the plant-wide process in a distributed manner, and a distributed fault localization approach based on recursive online state estimation. The distributed systems are formulated with an interaction-oriented dynamic model, which can represent generic communication and control networks, but is extremely difficult to identify the source of fault.

Index Terms—Plant-wide monitoring, distributed system, fault diagnosis, fault localization, distributed implementation.

## I. INTRODUCTION

In the framework of Industry 4.0, the concept of industrial cyber-physical systems is being introduced to the design and implementation of many practical large-scale processes [1–5]. Through various means of connections and multi-dimension networking, a number of physically distributed plants, control centers and computing centers compose “interactionoriented system-of-systems (SoS)”. However, while improving the management and control degree, monitoring and fault diagnosis of such SoS has become a major challenge [6, 7]. In the recent few years, plant-wide monitoring and fault diagnosis have received much attention from the related research fields, but with very limited research outcomes reported towards this specific challenge [1, 8–13].

Unlike the traditional single-system (including the largescale ones) monitoring problems, plant-wide monitoring need to address the following Key Issues: 1) How to tackle the coupling of states between the subsystems. 2) In the task of fault localization, i.e., finding the source of fault, how to deal with fault propagations along the networks. 3) How to achieve scalability and how to (self-) reconfigure after topology changes.

In [9], Luo et al. proposed a data-driven fog-computingaided adaptive monitoring approach with distributed configuration, where a central fusion node is needed to collect and broadcast the overall residual. In [10, 11], Parisini et al. proposed model-based scalable distributed residual generation approach based on modified fault detection filter for a type of interconnected systems. This work addressed the Key Issues 1 and 3 as defined above. With multi-variate analysis tools, a distributed parallel PCA based approach was proposed in [12] in the MapReduce framework. In [13], a distributed canonical correlation analysis based approach was presented, which adopts compressed information for communication between subsystems. Towards the Key Issue 2, the propagation mechanism of high frequency signals along the power grid was analyzed in [14] based on the transmission line theory. It revealed how the presence of faults will affect the signal propagation. An anomaly detection and localization approach was proposed in [15] for distributed smart grids where the Power Line Modems are used as sensors.

This paper addresses the first two Key Issues. The proposed approaches have the following novelties and advantages over the existing ones.

Firstly, the proposed distributed residual generation scheme is decentralized. The central node is unneeded. Consequently, many problems induced by the central fusion node can be avoided, such as the global synchronization problem resulting from various network-induced time delay. The robustness is improved due to the decentralized configuration.

Secondly, this work adopts interaction-oriented models where the subsystems’ output signals and send-information signals are also directly driven by the external states in addition to their local states.

Thirdly, the plant-wide process is partitioned into several regions where each has a Computing Center in charge of the corresponding residual generation task. This configuration is intended to make the best use of the available computing resources while making the distributed monitoring system more organized/hierarchical (so more robust against failures). Furthermore, it is proposed to build a pair of output residual generator and send-information residual generator at each Computing Center.

This research also works towards the problem of fault localization for the interaction-oriented systems, which is extremely difficult due to the mutual influences among the correlated subsystem states [16, 17]. A local fault will propagate along the network and trigger multiple alarms in the subsystems. In order to accurately identify the source of fault, it is necessary to disconnect some of the subsystems to suppress fault propagation. However, most of the existing localization approaches, such as [14, 15, 18–22] and the references therein, are oriented to the power grids and rely heavily on the dedicated devices and sensors for analysis. It is also required from the perspective of industrial practice to find the faults efficiently with minor changes in the system’s topology. To this end, it is proposed to first perform rough localization (solution based on Sec. III), and then perform accurate localization (based on Sec. IV).

## II. SYSTEM DESCRIPTION, ASSUMPTIONS AND PROBLEM FORMULATION

This section firstly introduces the interaction-oriented model of distributed dynamic systems [23], and an equivalent crossstate interconnected model.

Interaction-oriented model (Model 1):

$$
\begin{array} { l l l } { x _ { i , k + 1 } } & { = } & { A _ { i } x _ { i , k } + B _ { i } u _ { i , k } + E _ { i } t _ { i , k } + w _ { i , k } } \end{array}\tag{1}
$$

$$
\begin{array} { r c l } { y _ { i , k } } & { = } & { C _ { i } x _ { i , k } + D _ { i } u _ { i , k } + F _ { i } t _ { i , k } + v _ { i , k } } \end{array}\tag{2}
$$

$$
\begin{array} { r c l } { s _ { i , k } } & { = } & { C _ { s , i } x _ { i , k } + D _ { s , i } u _ { i , k } + F _ { s , i } t _ { i , k } } \end{array}\tag{3}
$$

$$
\begin{array} { r c l } { t _ { i , k } } & { = } & { \Sigma _ { j \in { \mathcal N } _ { i } } M _ { i j } s _ { j , k } } \end{array}\tag{4}
$$

where $x _ { i }$ , $u _ { i }$ and $y _ { i }$ denote the state variables, inputs and outputs of subsystem i. $w _ { i }$ and $v _ { i }$ are stochastic process noise and measurement noise with known covariance matrices, denoted by $\Sigma _ { w } .$ i and $\Sigma _ { v _ { i } }$ , respectively. $s _ { i }$ denotes the sendinformation from node i to the adjacent nodes, $t _ { i }$ denotes the taken information from the adjacent nodes to node i, and $M _ { i j }$ is the modulation matrix which characterize how the information is received from thPlant-Wide Monitoring and Fault Localization for Interaction-Oriented Distributed Systems. 不详.
e other nodes for different subsystems. ${ \mathcal { N } } _ { i }$ denotes the set of all connected (neighbor) nodes of subsystem i. Without loss of generality, in this work the sent information $s _ { i }$ is not driven by $t _ { i } ,$ i.e., $F _ { s , i } = 0$ Fully interconnected model (Model 2):

$$
x _ { i , k + 1 } = A _ { i i } x _ { i , k } + \overline { { B _ { i } u _ { i } } } | _ { k } + \Sigma _ { j } \ A _ { i j } x _ { j , k } + w _ { i , k }\tag{5}
$$

$$
y _ { i , k } = C _ { i i } x _ { i , k } + \overline { { D _ { i } u _ { i } } } | _ { k } + \Sigma _ { j } ~ C _ { i j } x _ { j , k } + v _ { i , k }\tag{6}
$$

where $\overline { { B _ { i } u _ { i } } }$ and $\overline { { D _ { i } u _ { i } } }$ denote the known inputs that are driven by not only the local control demand, but also the adjacent subsystems’ control demands. $A _ { i j }$ and $C _ { i j }$ are the cross-state matrices.

The correspondence of Model 1 and Model 2 can be derived and written as

$$
A _ { i i } = A _ { i } , A _ { i j } = E _ { i } \Sigma _ { j \in { \mathcal { N } } _ { i } } M _ { i j } C _ { s , j }\tag{7}
$$

$$
C _ { i i } = C _ { i } , \quad \quad C _ { i j } = F _ { i } \Sigma _ { j \in \mathcal { N } _ { i } } M _ { i j } C _ { s , j }\tag{8}
$$

$$
\overline { { B _ { i } u _ { i } } } = B _ { i } u _ { i } + E _ { i } \Sigma _ { j \in { \mathcal { N } } _ { i } } M _ { i j } D _ { s , j } u _ { j }\tag{9}
$$

$$
\overline { { D _ { i } u _ { i } } } = D _ { i } u _ { i } + F _ { i } \Sigma _ { j \in { \mathcal { N } } _ { i } } M _ { i j } D _ { s , j } u _ { j }\tag{10}
$$

Assumptions: The system is described with Model 1 (or Model 2) with known interaction configurations. There are totally Ω Computing Centers available, and the process data of each subsystem are sent to one geographically adjacent Computing Center (See Fig. 1). Assume the ωth Computing Center is in charge of subsystems $\{ S _ { \omega _ { 1 } } , \cdot \cdot \cdot , S _ { \omega _ { n _ { \omega } } } \}$ where $n _ { \omega }$ is the number of subsystems that corresponds to the ωth Computing Center. The noise and delay in the transmission of information can be omitted. For fault isolation and localization purpose, part of the connections between the subsystems can be cancelled with guaranteed system stability.

Problem 1. Let the above “Assumptions” hold. For plantwide process monitoring, develop a set of residual generators driven only by regional input/output data such as to achieve distributed computation at the available Computing Centers.

Problem 2. Let the above “Assumptions” hold. Develop a fast approach to localize the source of faults. High efficiency and minor changes in the system’s topology are two practically desired factors.

<!-- image-->  
C? — the ?-th computing center Si — the i -th subsystem (local plants)  
Fig. 1. Schematics layout of the distributed fault diagnosis system for plantwide monitoring

## III. PLANT-WIDE MONITORING APPROACH WITH DISTRIBUTED IMPLEMENTATION

## A. Offline design approach

Consider Model 2, introduce the following notations to derive a plant-wide model of all subsystems.

$$
\begin{array} { l l } { B = \{ B _ { i j } \} = \left\{ \begin{array} { l l } { B _ { i } } & { ( i = j ) } \\ { E _ { i } M _ { i j } D _ { s , j } } & { ( i \neq j ) } \end{array} \right. } \\ { D = \{ D _ { i j } \} = \left\{ \begin{array} { l l } { D _ { i } } & { ( i = j ) } \\ { F _ { i } M _ { i j } D _ { s , j } } & { ( i \neq j ) } \end{array} \right. } \end{array}\tag{11}
$$

$$
\xi = \left[ \begin{array} { c } { \xi _ { 1 } } \\ { \vdots } \\ { \vdots } \\ { \xi _ { n _ { s } } } \end{array} \right] , \quad \Xi = \left[ \begin{array} { c c c } { \Xi _ { 1 1 } } & { \cdot \cdot \cdot } & { \Xi _ { 1 n _ { s } } } \\ { \vdots } & & { \vdots } \\ { \Xi _ { n _ { s } 1 } } & { \cdot \cdot \cdot } & { \Xi _ { n _ { s } n _ { s } } } \end{array} \right]\tag{12}
$$

where x, u, w, y and v are defined in the form of $\xi ,$ and A and $C$ are defined in the form of $\Xi .$

$$
x _ { k + 1 } = A x _ { k } + B u _ { k } + w _ { k }\tag{13}
$$

$$
y _ { k } = C x _ { k } + D u _ { k } + v _ { k }\tag{14}
$$

Denote $\begin{array} { r } { u _ { \omega } = \big [ u _ { \omega _ { 1 } } ^ { T } \quad \cdot \cdot \cdot \quad u _ { \omega _ { u _ { \omega } } } ^ { T } \big ] ^ { T } , y _ { \omega } = [ y _ { \omega _ { 1 } } ^ { T } \quad \cdot \cdot \cdot \quad y _ { \omega _ { n _ { \omega } } } ^ { T } ] ^ { T } , } \end{array}$ and $s _ { \omega } = \left[ s _ { \omega _ { 1 } } ^ { T } \mathrm { ~ \quad ~ } \cdot \cdot \mathrm { ~ \quad ~ } s _ { \omega _ { n _ { \omega } } } ^ { T } \right] ^ { T }$

Consider the residual generators in the following forms

$$
z _ { \omega , k + 1 } = A _ { z , \omega } z _ { \omega , k } + B _ { z , \omega } u _ { \omega , k } + L _ { z , \omega } y _ { \omega , k } + L _ { r , \omega } r _ { \omega , k } ^ { y }
$$

$$
r _ { \omega , k } ^ { y } = G _ { z , \omega } ^ { y } y _ { \omega , k } - C _ { z , \omega } ^ { y } z _ { \omega , k } - D _ { z , \omega } ^ { y } u _ { \omega , k }\tag{15}
$$

$$
z _ { \omega , k + 1 } ^ { s } = A _ { z , \omega } ^ { s } z _ { \omega , k } ^ { s } + B _ { z , \omega } ^ { s } u _ { \omega , k } + L _ { z , \omega } ^ { s } s _ { \omega , k } + L _ { r , \omega } ^ { s } r _ { \omega , k } ^ { s }\tag{16}
$$

$$
r _ { \omega , k } ^ { s } = G _ { z , \omega } ^ { s } s _ { \omega , k } - C _ { z , \omega } ^ { s } z _ { \omega , k } - D _ { z , \omega } ^ { s } u _ { \omega , k }\tag{17}
$$

(18)

It is observed that Eqs. (15) (16) and (17) (18) are in similar forms, with an only difference that the output residual is driven by $y _ { \omega }$ while the send-information residual is driven by $s _ { \omega }$ . The following derivations will be based on Eqs. (15) and (16), and the superscripts are omitted. Similar results can be obtained for (17) and (18).

In this setup, each residual generator relies on only the local information $( u _ { \omega } , \ y _ { \omega } , \ r _ { \omega } )$ . A central node that collects and broadcasts the overall residual $( r _ { a l l } )$ [9] is unnecessary. In the below analysis and derivations, the influence of the cross-state terms $A _ { i j } x _ { j }$ is addressed during the design phase where the inputs and outputs of all the subsystems are needed to calculate relevant matrices of the plant-wide residual generator. Then, the plant-wide residual generator can be divided into multiple units for distributed computation purpose (N.B., not for local residual generation.)

Introduce the following notations to derive a plant-wide observer based residual generator

$$
z = \left[ \begin{array} { c } { z _ { 1 } } \\ { \vdots } \\ { z _ { \Omega } } \end{array} \right] , r _ { a l l } = \left[ \begin{array} { c } { r _ { 1 } } \\ { \vdots } \\ { r _ { \Omega } } \end{array} \right] , \Lambda _ { z } = \left[ \begin{array} { c c c } { \Lambda _ { z , 1 } } & & \\ & { \ddots } & \\ & & { \Lambda _ { z , \Omega } } \end{array} \right]\tag{19}
$$

where $A _ { z } , B _ { z } , L _ { z } , L _ { r } , G _ { z } , C _ { z }$ , and $D _ { z }$ are defined in the form of $\Lambda _ { z } .$

$$
z _ { k + 1 } = A _ { z } z _ { k } + B _ { z } u _ { k } + L _ { z } y _ { k } + L _ { r } r _ { a l l , k }\tag{20}
$$

$$
r _ { a l l , k } = G _ { z } y _ { k } - C _ { z } z _ { k } - D _ { z } u _ { k }\tag{21}
$$

$$
= G _ { z } C x _ { k } - C _ { z } z _ { k } + ( G _ { z } D - D _ { z } ) u _ { k } + G _ { z } v _ { k }\tag{22}
$$

Theorem 1. (Plant-wide residual generator design) Consider a large-scale system composed of a series of subsystems described by Model 2. With the notations in (11), (12) and (19), if the Luenberger condition $T A - L _ { z } C = A _ { z } T _ { \mathrm { { f } } }$ $T B - B _ { z } - L _ { z } D = 0 , G _ { z } C = C _ { z } T , G _ { z } D - D _ { z } = 0$ holds, then a plant-wide residual generator can be constructed with (20) and (21). In the normal working condition, the expectation of the residual signal is zero and the covariance matrix follows Eq. (26).

Proof. Let the state estimation error be denoted by $e _ { k } =$ $T x _ { k } \mathrm { ~ - ~ } z _ { k }$ . Then, according to Eqs. (13), (20) and (14), the error dynamics can be derived as

$$
\begin{array} { l c l } { { e _ { k + 1 } } } & { { = } } & { { T x _ { k + 1 } - z _ { k + 1 } } } \\ { { } } & { { = } } & { { T A x _ { k } + T B u _ { k } + T w _ { k } } } \\ { { } } & { { } } & { { - A _ { z } z _ { k } - B _ { z } u _ { k } - L _ { z } y _ { k } - L _ { r } r _ { a l l , k } } } \\ { { } } & { { = } } & { { ( T A - L _ { z } C ) x _ { k } - A _ { z } z _ { k } + } } \\ { { } } & { { } } & { { ( T B - B _ { z } - L _ { z } D ) u _ { k } + } } \\ { { } } & { { } } & { { ( T w _ { k } - L _ { z } v _ { k } ) - L _ { r } r _ { a l l , k } } } \end{array}
$$

Let $T A - L _ { z } C = A _ { z } T , T B - B _ { z } - L _ { z } D = 0$ , then the above equation is simplified as

$$
e _ { k + 1 } = A _ { z } e _ { k } + ( T w _ { k } - L _ { z } v _ { k } ) - L _ { r } r _ { a l l , k }\tag{23}
$$

Let $G _ { z } C = C _ { z } T , G _ { z } D - D _ { z } = 0$ , according to $( 2 2 ) , r _ { a l l , k } =$ $( A _ { z } - L _ { r } C _ { z } ) e _ { k } + ( T w _ { k } - ( L _ { z } + L _ { r } G _ { z } ) v _ { k } ) ^ { }$ Denote $\begin{array} { r } { \dot { A } _ { z } = \ddot { A } _ { z } - { L _ { r } } \dot { C } _ { z } , \dot { \Delta } _ { k } = T \dot { w } _ { k } - ( \ddot { L _ { z } } + L _ { r } G _ { z } ) v _ { k } , } \end{array}$ then $e _ { k + 1 } = A _ { z } e _ { k } + \Delta _ { k } . \ \mathbf { B } \mathbf { y }$ designing $L _ { r }$ such that $A _ { z }$ is Schur stable, $\begin{array} { r } { \operatorname* { l i m } _ { p \to \infty } A _ { z } ^ { p } = 0 . } \end{array}$ Based on recursive computation,

$$
e ( k + p ) = A _ { z } ^ { p } e _ { k } + \left[ A _ { z } ^ { p - 1 } \quad \cdot \cdot \cdot \quad I \right] \left[ \begin{array} { c } { { \Delta _ { k } } } \\ { { \vdots } } \\ { { \Delta ( k + p - 1 ) } } \end{array} \right]\tag{24}
$$

Because $\mathbb { E } [ w _ { k } ] = \mathbb { E } [ v _ { k } ] = 0$ , it holds that $k \to \infty , \mathbb { E } [ e _ { k } ] = 0$ and $\mathbb { E } [ r _ { a l l , k } ] = 0$ . In this paper, we denote the covariance matrix of x by $\Sigma _ { x }$ , then

$$
\begin{array} { c } { { \Sigma _ { e ( k + p ) } = \mathbb { E } [ e ( k + p ) e ( k + p ) ^ { T } ] } } \\ { { = \left[ A _ { z } ^ { p - 1 } \quad . . . \quad I \right] \left[ \begin{array} { c c c } { { \Sigma _ { \Delta } } } & { { } } & { { } } \\ { { } } & { { \ddots } } & { { } } \\ { { } } & { { } } & { { \Sigma _ { \Delta } } } \end{array} \right] \left[ \begin{array} { c } { { ( A _ { z } ^ { p - 1 } ) ^ { T } } } \\ { { \vdots } } \\ { { ( A _ { z } ) ^ { T } } } \\ { { \ I } } \end{array} \right] } } \\ { { = \Sigma _ { i = 0 } ^ { p - 1 } \ A _ { z } ^ { i } \cdot \Sigma _ { \Delta } \cdot ( A _ { z } ^ { i } ) ^ { T } } } \end{array}\tag{25}
$$

where $\Sigma _ { \Delta } = T \Sigma _ { w } T ^ { T } + ( L _ { z } + L _ { r } C _ { z } ) \Sigma _ { v } ( L _ { z } + L _ { r } C _ { z } ) ^ { T }$ . Here, $\Sigma _ { w } = d i a g \ _ { i = 1 } ^ { n _ { s } } \{ \Sigma _ { w _ { i } } \} , \ \Sigma _ { v } = d i a g \ _ { i = 1 } ^ { n _ { s } } \{ \Sigma _ { v _ { i } } \}$ , Furthermore,

$$
\begin{array} { l c l } { { \Sigma _ { r _ { a l l } } } } & { { = } } & { { \mathbb { E } [ r _ { a l l } r _ { a l l } ^ { T } ] } } \\ { { } } & { { = } } & { { C _ { z } \Sigma _ { \Delta } C _ { z } ^ { T } + G _ { z } \Sigma _ { v } G _ { z } ^ { T } } } \end{array}\tag{26}
$$

According to the above definitions, it is straightforward that $\Sigma _ { r _ { a l l } }$ is a block diagonal matrix where $\Sigma _ { r _ { \omega } } ~ ( \omega = 1 , \cdot \cdot \cdot , \Omega )$ can be extracted.

Theorem 2. (Distributed implementation of residual generators at Computing Centers) Let the assumptions in Theorem 1 hold. A total of Ω pairs of output residual generators and send-information residual generators defined as (15)—(18) can be deployed at the Computing Centers, and jointly monitor the health status of the plant-wide system.

Proof. The proof is straightforward from the above analysis and derivations.

Remark 1. It should be noted that $\mathbb { E } [ e ] = 0 \Rightarrow \mathbb { E } [ e _ { \omega } ] =$ $\mathbb { E } [ T _ { \omega } x - z _ { \omega } ] = 0$ where $T _ { \omega }$ is the ωth row of $T ,$ indicating that $z _ { \omega }$ is an unbiased estimation of $T _ { \omega } x$ , and $z _ { \omega }$ (and also $r _ { \omega } )$ is dependent to all the state variables rather than only the local ones $x _ { \omega }$ . As a result, the observer based residual generator is incapable of determining the source of the faults. Specifically, an alarm raised at Computing Center $\omega$ cannot indicate there is a fault in the corresponding subsystems (could be from external subsystems).

B. Online monitoring approach & Analysis of fault detectability

The $T ^ { 2 }$ statistics of the residuals corresponding to the ωth Computing Center is calculated by

$$
J _ { T ^ { 2 } , \omega } = r _ { \omega } ^ { T } \left( \Sigma _ { r _ { \omega } } \right) ^ { - 1 } r _ { \omega } = \| \Sigma _ { r _ { \omega } } ^ { - 1 / 2 } r _ { \omega } \| _ { \mathcal { L } _ { 2 } } ^ { 2 }\tag{27}
$$

The threshold $J _ { t h , \omega }$ can be calculated with the generalized likelihood ratio (GRL) based approach. The fault diagnosis logic can be summarized as

$$
\left\{ \begin{array} { l l } { \mathcal { O R } \overset { \Omega } { \omega = 1 } \left( J _ { T ^ { 2 } , \omega } > J _ { t h , \omega } \right) } & { \Rightarrow \mathrm { ~ F a u l t y ~ } } \\ { \mathcal { A N D } \overset { \Omega } { \omega = 1 } \left( J _ { T ^ { 2 } , \omega } \leq J _ { t h , \omega } \right) } & { \Rightarrow \mathrm { ~ f a u l t - f r e e ~ } } \end{array} \right.\tag{28}
$$

Denote the outputs, residuals and test statistics in the faultfree condition with $y _ { \omega } ^ { 0 } , r _ { \omega } ^ { 0 }$ , and $J _ { T ^ { 2 } , \omega } ^ { 0 }$ respectively. Consider a measurement fault $f _ { y }$ such that $\begin{array} { r } { \bar { y } _ { \omega } = y _ { \omega } ^ { 0 } + \Psi _ { y } f _ { y } } \end{array}$ . Recall that ${ r } _ { \omega , k } = G _ { z , \omega } y _ { \omega , k } - C _ { z , \omega } z _ { \omega , k } - D _ { z , \omega } u _ { \omega , k }$ , it can be derived that

$$
\begin{array} { r l r } { J _ { T ^ { 2 } , \omega } } & { { } = } & { \Vert \Sigma _ { r _ { \omega } } ^ { - 1 / 2 } ( r _ { \omega } ^ { 0 } + G _ { z , \omega } \Psi _ { y } f _ { y } ) \Vert ^ { 2 } } \end{array}\tag{29}
$$

$$
\begin{array} { r l } { \geq } & { { } \| \Sigma _ { r _ { \omega } } ^ { - 1 / 2 } G _ { z , \omega } \Psi _ { y } f _ { y } \| ^ { 2 } - J _ { T ^ { 2 } , \omega } ^ { 0 } } \end{array}\tag{30}
$$

If for $\forall J _ { T ^ { 2 } , \omega } ^ { 0 } ,$ , it holds that $J _ { T ^ { 2 } , \omega } > J _ { t h , \omega }$ , i.e., the fault can be detected, we must have $\| \Sigma _ { r _ { \omega } } ^ { - 1 / 2 } G _ { z , \omega } \Psi _ { y } f _ { y } \| ^ { 2 } > J _ { t h , \omega } +$ $\operatorname* { s u p } ( J _ { T ^ { 2 } , \omega } ^ { 0 } )$ . To minimize the false alarm rate (FAR), it is assumed that sup $\langle J _ { T ^ { 2 } , \omega } ^ { 0 } ) \leq J _ { t h , \omega }$ . Accordingly, the fault is detectable with probability 1 iff $\begin{array} { r } { \| \Sigma _ { r _ { \omega } } ^ { - 1 / 2 } G _ { z , \omega } \Psi _ { y } f _ { y } \| ^ { 2 } > 2 J _ { t h , \omega } . } \end{array}$ Following the norm property, $\begin{array} { r l } { \Vert \Sigma _ { r _ { \omega } } ^ { - 1 / 2 } G _ { z , \omega } \Psi _ { y } \Vert ^ { 2 } \Vert f _ { y } \Vert ^ { 2 } } & { { } \ge } \end{array}$ $\| \Sigma _ { r _ { \omega } } ^ { - 1 / 2 } G _ { z , \omega } \Psi _ { y } f _ { y } \| ^ { 2 }$ and $\| f _ { y } \| _ { \mathcal { L } _ { 2 } } = | f _ { y } |$ . Therefore,

$$
| f _ { y } | > \frac { \sqrt { 2 J _ { t h , \omega } } } { \Vert \Sigma _ { r _ { \omega } } ^ { - 1 / 2 } G _ { z , \omega } \Psi _ { y } \Vert }\tag{31}
$$

Similar results can be obtained for actuator faults: If an actuator fault is denoted by $f _ { u }$ such that $u _ { \omega } = u _ { \omega } ^ { 0 } + \Psi _ { u } f _ { u }$ , it is detectable with probability 1 iff

$$
| f _ { u } | > \frac { \sqrt { 2 J _ { t h , \omega } } } { \| \Sigma _ { \omega } ^ { - 1 / 2 } D _ { z , \omega } \Psi _ { u } \| }\tag{32}
$$

## IV. FAULT LOCALIZATION

In this part, a recursive filter based estimation approach proposed in [24] is employed and modified to adapt to the fault localization purpose. To be consistent with the plantwide monitoring framework presented above, an equivalent form of Model 2 based on unknown input representation is firstly presented.

Unknown input representation (Model 3): The influence of the connected subsystems’ states are treated as unknown inputs $d _ { i , k }$

$$
\begin{array} { r c l } { x _ { i , k + 1 } } & { = } & { A _ { i } x _ { i , k } + \overline { { B _ { i } u _ { i } } } | _ { k } + G _ { i } d _ { i , k } + w _ { i , k } } \end{array}\tag{33}
$$

$$
\begin{array} { r c l } { y _ { i , k } } & { = } & { C _ { i } x _ { i , k } + \overline { { D _ { i } u _ { i } } } | _ { k } + H _ { i } d _ { i , k } + v _ { i , k } } \end{array}\tag{34}
$$

satisfying $r a n k ( C _ { i } G _ { i } ) = r a n k ( G _ { i } ) = r a n k ( H _ { i } ) = d i m ( d _ { i } )$ For emphasis, denote $x _ { a l l } = \overset { \cdot } { x } \overset { \cdot } { = } [ x _ { 1 } ^ { T } x _ { 2 } ^ { T } \cdot \cdot \cdot x _ { n _ { s } } ^ { T } ] ^ { T }$ . We define $\hat { E } _ { i j } | _ { j \notin { \mathcal N } _ { i } } = 0 , F _ { i j } | _ { j \notin { \mathcal N } _ { i } } = 0$ , and introduce the compact notation

$$
\Sigma _ { j \in \mathcal { N } _ { i } } \ E _ { i j } x _ { j } = r o w _ { j \in \mathcal { N } _ { i } } ( E _ { i j } ) \ c o l _ { j \in \mathcal { N } _ { i } } ( x _ { j } ) = E _ { [ i , : ] } x _ { a l l }\tag{35}
$$

$$
\Sigma _ { j \in \mathcal { N } _ { i } } \ F _ { i j } x _ { j } = r o w _ { j \in \mathcal { N } _ { i } } ( F _ { i j } ) \ c o l _ { j \in \mathcal { N } _ { i } } ( x _ { j } ) = F _ { [ i , : ] } x _ { a l l }\tag{36}
$$

To meet the above rank condition, dual LQ (QR) decomposition of $E _ { [ i , : ] }$ and $F _ { [ i , : ] }$ is performed

$$
G _ { i } d _ { i } = E _ { [ i , : ] } x _ { a l l } = L _ { E _ { [ i , : ] } } Q _ { E _ { [ i , : ] } } x _ { a l l }\tag{37}
$$

$$
H _ { i } d _ { i } = F _ { [ i , : ] } x _ { a l l } = L _ { F _ { [ i , : ] } } Q _ { F _ { [ i , : ] } } x _ { a l l }\tag{38}
$$

Let $U _ { i } = Q _ { E _ { [ i , : ] } } Q _ { F _ { [ i , : ] } } ^ { T }$ , then $Q _ { E _ { [ i , : ] } } = U _ { i } Q _ { F _ { [ i , : ] } } : = Q _ { i }$ . The correspondence of Model 2 and Model 3 can be written as

$$
G _ { i } = L _ { E _ { [ i , : ] } } , H _ { i } = L _ { F _ { [ i , : ] } } U _ { i } , d _ { i } = Q _ { i } x _ { a l l }\tag{39}
$$

A. Modified recursive filter for the online estimation of states and unknown inputs

Assume that $\hat { x } _ { i , k | k - 1 }$ is an unbiased estimation of the previous state of subsystem i. The goal is to derive an

<!-- image-->  
Fig. 2. Fault propagation along the interaction network and fault localization mechanism (Assume that a fault occurs in Si)

unbiased estimation of the next state $\hat { x } _ { i , k + 1 | k }$ . The procedure of recursive estimation consists of five steps.

$$
\begin{array} { r l r } { \mathrm { S 1 } \colon } & { { } } & { \tilde { y } _ { i , b , k } = y _ { i , k } - C _ { i } \hat { x } _ { i , k | k - 1 } - \overline { { D _ { i } u _ { i } } } | _ { k } } \end{array}\tag{40}
$$

$$
\begin{array} { r l r } { \mathrm { S } 2 \mathrm { : } } & { { } } & { \hat { d } _ { i , k } = M _ { i , k } \tilde { y } _ { i , b , k } } \end{array}\tag{41}
$$

$$
\begin{array} { r l r } { \mathrm { S 3 : } } & { { } \ } & { \tilde { y } _ { i , u b , k } = y _ { i , k } - C _ { i } \hat { x } _ { i , k | k - 1 } - H _ { i } \hat { d } _ { i , k } } \end{array}\tag{42}
$$

$$
\begin{array} { r l r } { \mathrm { S } 4 \mathrm { : } } & { { } } & { \hat { x } _ { i , k | k } = \hat { x } _ { i , k | k - 1 } + K _ { i , k } \tilde { y } _ { i , u b , k } } \end{array}\tag{43}
$$

$$
{ \sf S } 5 \colon \quad \tau _ { i , k + 1 | k } = A _ { i } \hat { x } _ { i , k | k } + \overline { { B _ { i } u _ { i } } } | _ { k } + G _ { i } \hat { d } _ { i , k }\tag{44}
$$

S1) Calculate biased innovation vector. S2) Obtain the unbiased unknown input estimation with a filter matrix $M _ { i , k }$ to be designed. The unbiasedness was proved in [24]. S3) Calculate the unbiased innovation based on the previous two steps. S4) Perform minimum variance state estimation with a Kalman filter gain matrix $K _ { i , k }$ to be designed. S5) Predict the unbiased next state via forward recurrence. The following solutions can be obtained following [24], and the symbols are rewritten to be consistent with this paper.

Solution to $M _ { i , k }$ and $K _ { i , k } \colon$

$$
\Sigma _ { e _ { y _ { i } , k } } = C _ { i } \cdot \Sigma _ { \tilde { x } _ { i , k | k - 1 } } \cdot C _ { i } ^ { T } + \Sigma _ { v _ { i } }\tag{45}
$$

$$
M _ { i , k } = \left( H _ { i } ^ { T } \cdot \Sigma _ { e _ { y _ { i } , k } } ^ { - 1 } \cdot H _ { i } \right) ^ { - 1 } \cdot H _ { i } ^ { T } \cdot \Sigma _ { e _ { y _ { i } , k } } ^ { - 1 }\tag{46}
$$

$$
K _ { i , k } = \Sigma _ { \tilde { x } _ { i , k \mid k - 1 } } \cdot C _ { i } ^ { T } \cdot \Sigma _ { e _ { y _ { i } , k } } ^ { - 1 }\tag{47}
$$

Recursive calculation of $\Sigma _ { \tilde { x } _ { i , k \mid k - 1 } } :$

$$
\begin{array} { r l } & { \quad \Sigma _ { \tilde { d } _ { i , k } } = \left( H _ { i } ^ { T } \cdot \Sigma _ { e _ { y _ { i } , k } } ^ { - 1 } \cdot H _ { i } \right) ^ { - 1 } } \\ & { \sum _ { \tilde { x } _ { i , k \mid k } = } \Sigma _ { \tilde { x } _ { i , k \mid k - 1 } } - K _ { i , k } \left( \Sigma _ { e _ { y _ { i } , k } } - H _ { i } \Sigma _ { \tilde { d } _ { i , k } } H _ { i } ^ { T } \right) K _ { i , k } ^ { T } } \\ & { \Sigma _ { \tilde { x } _ { i , k } , \tilde { d } _ { i , k } } = \Sigma _ { \tilde { d } _ { i , k } , \tilde { x } _ { i , k } } ^ { T } = - K _ { i , k } H _ { i } \cdot \Sigma _ { \tilde { d } _ { i , k } } } \\ & { \sum _ { \tilde { x } _ { i , k + 1 \mid k } = } \left[ A _ { i } \quad G _ { i } \right] \left[ \Sigma _ { \tilde { x } _ { i , k \mid k } } ^ { \Sigma _ { \tilde { x } _ { i , k \mid k } } } \quad \Sigma _ { \tilde { x } _ { i , k } , \tilde { d } _ { i , k } } \right] . } \\ & { \qquad \quad \Sigma _ { \tilde { d } _ { i , k } , \tilde { x } _ { i , k } } \quad \quad \quad \quad \left( \left[ A _ { i } \quad G _ { i } \right] \right) ^ { T } + \Sigma _ { w _ { i } } } \end{array}
$$

Rough localization based on Sec. III   
Cancel the interactions between regional functional units (such as the Computing Centers, as shown in $\mathrm { F i g . } \ 2 .$   
If $J _ { T ^ { 2 } , \omega } > J _ { t h , \omega } ,$ further examine subsystems in the ωth region. Precise localization based on Sec. IV   
Select a suspicious subsystem i based on maintenance priority or expert knowledge while ensuring the subsystems’ stability. Cancel the “send information” from $S _ { i }$ to other systems.   
For $\forall j \in S _ { \omega } , j \neq i ,$ the source of fault is in $S _ { i } { \mathrm { ~ i \dot { f } ~ } }$   
$\hat { x } _ { j , k } ^ { ( i ) }  \hat { x } _ { j , k | k - 1 }$ AND $\hat { x } _ { j , k } ^ { ( q ) } \to \hat { x } _ { j , k | k - 1 }$ (q ∈ Sω , q 6= i, j) Otherwise, $\hat { x } _ { j , k } ^ { ( i ) } \to \hat { x } _ { j , k | k - 1 }$ (both estimations are erroneous), the source of fault is not in $S _ { i } .$ . Check next suspicious subsys.

## B. Interaction-oriented system fault localization

According to Eq. (39), the estimation of plant-wide states by subsystem j is calculated as $\hat { x } _ { a l l , k } = Q _ { j } ^ { T } \hat { d } _ { j , k }$ where $j =$ $1 , \cdots , n _ { s } , j \neq i$ . Extract the ith block vector from the plantwide states (estimated by subsystem $j )$ to obtain the state estimation of subsystem i: $\hat { x } _ { i , k } ^ { ( j ) } \overset { \cdot } { = } ( \hat { x } _ { a l l , k } ) _ { [ i , : ] }$

As shown in Fig. 2, if the subsystem with fault source only receives but does not send information, i.e., $M _ { [ i , : ] } = 0 ,$ its states cannot be estimated by others. But it can still calculate (erroneous) estimates of others’ states, which will deviate from the true values (See Table I, $\hat { x } _ { j , k } ^ { ( i ) } \ \not \to \ \hat { x } _ { j , k | k - 1 } )$ because the input data $u _ { i }$ or yi that drive the recursive estimation procedure (40)–(44) is faulty.

If the send information of a fault-free subsystem is cancelled, the propagation routine of fault is still not blocked. In this circumstance, the subsystems will generate matched but erroneous estimations because they are driven by the same faulty $u _ { \omega }$ and $y _ { \omega }$ . (See Table I, $\hat { x } _ { j , k } ^ { ( i ) } \to \hat { x } _ { j , k | k - 1 } . \mathrm { ) }$

Based on the above analysis, a fault localization scheme is summarized in Table I.

## V. SIMULATION STUDY

## VI. CONCLUSION

## Future work

## REFERENCES

[1] S. Xie, Y. Xie, H. Ying, Z. Jiang, and W. Gui, “Neurofuzzy-based plant-wide hierarchical coordinating optimization and control: An application to zinc hydrometallurgy plant,” IEEE Trans. Ind. Electron., 2019. [Online]. Available: DOI:10.1109/TIE.2019.2902790

[2] H. Chen, B. Jiang, N. Lu, and Z. Mao, “Deep pca based realtime incipient fault detection and diagnosis methodology for electrical drive in high-speed trains,” IEEE Transactions on Vehicular Technology, vol. 67, no. 6, pp. 4819–4830, 2018.

[3] H. Chen, B. Jiang, and N. Lu, “An improved incipient fault detection method based on kullback-leibler divergence,” ISA Transactions, 2018. [Online]. Available: https://doi.org/10. 1016/j.isatra.2018.05.007

[4] H. Luo, X. Yang, M. Kruger, S. Ding, and K. Peng, “A plug-and-play monitoring and control architecture for disturbance compensation in rolling mills,” IEEE/ASME Transactions on Mechatronics. [Online]. Available: DOI: 10.1109/TMECH.2016.2636337

[5] S. Sridhar, A. Hahn, and M. Govindarasu, “Cyber physical system security for the electric power grid,” Proceedings of the IEEE, vol. 100, no. 1, pp. 210–224, 2012.

[6] O. Abdeljaber, S. Sassi, O. Avci, S. Kiranyaz, A. A. Ibrahim, and M. Gabbouj, “Fault detection and severity identification of ball bearings by online condition monitoring,” IEEE Trans. Ind. Electro., vol. 66, no. 10, pp. 8136–8147, 2019.

[7] Z. Gao, X. Liu, and M. Z. Q. Chen, “Unknown input observerbased robust fault estimation for systems corrupted by partially decoupled disturbances,” IEEE Transactions on Industrial Electronics, vol. 63, no. 4, 2016.

[8] J. Ding, H. Modares, T. Chai, and F. L. Lewis, “Data-based multiobjective plant-wide performance optimization of industrial processes under dynamic environments,” IEEE trans. Ind. Informat., vol. 12, no. 2, pp. 454–465, 2016.

[9] H. Luo, H. Zhao, and S. Yin, “Data-driven design of fog computing aided process monitoring system for large-scale industrial processes,” IEEE Trans. Ind. Informat., vol. 14, no. 10, pp. 4631–4641, 2018.

[10] F. Boem, R. Carli, M. Farina, G. Ferrari-Trecate, and T. Parisini, “Distributed fault detection for interconnected large-scale systems: A scalable plug & play approach,” IEEE Transactions on Control of Networked Systems, vol. 6, no. 2, pp. 800–811, 2019.

[11] C. Keliris, M. Polycarpou, and T. Parisini, “A distributed fault detection filtering approach for a class of interconnected continuous-time nonlinear systems,” IEEE Transactions on Automatic Control, vol. 58, no. 8, pp. 2032–2047, 2013.

[12] J. Zhu, Z. Ge, and Z. Song, “Distributed parallel pca for modeling and monitoring of large-scale plant-wide processes with big data,” IEEE Trans. Ind. Informat., vol. 13, no. 4, pp. 1877–1885, 2017.

[13] Z. Chen, Y. Cao, S. X. Ding, K. Zhang, T. Koenings, T. Peng, C. Yang, and W. Gui, “A distributed canonical correlation analysis-based fault detection method for plant-wide process monitoring,” IEEE trans. Ind. Informat., vol. 15, no. 5, 2710– 2720.

[14] F. Passerini and A. M. Tonello, “Smart grid monitoring using power line modems: Effect of anomalies on signal propagation,” IEEE Access, vol. 7, pp. 27 302–27 312, 2019.

[15] “Smart grid monitoring using power line modems: Anomaly detection and localization,” IEEE Transactions on Smart Grid, 2019. [Online]. Available: DOI:10.1109/TSG. 2019.2899264

[16] M. Kazim, A. H. Khawaja, U. Zabit, and Q. Huang, “Fault detection and localization for overhead 11 kv distribution lines with magnetic measurements,” IEEE Transactions on Instrumentation and Measurement, 2019. [Online]. Available: DOI:10.1109/TIM.2019.2920184

[17] S. M. Srinivasan, T. Truong-Huu, and M. Gurusamy, “Machine learning-based link fault identification and localization in complex networks,” IEEE Internet of Things Journal, 2019. [Online]. Available: DOI:10.1109/JIOT.2019.2908019

[18] F. Deng, Z. Chen, M. R. Khan, and R. Zhu, “Fault detection and localization method for modular multilevel converters,” vol. 30, no. 5, pp. 2721–2732, 2015.

[19] H. F. Habib, T. Youssef, M. H. Cintuglu, and O. A. Mohammed, “Multi-agent-based technique for fault location, isolation, and service restoration,” IEEE Trans. Industry Applications, vol. 53, no. 3, pp. 1841–1851, 2017.

[20] A. Vempaty, Y. S. Han, and P. K. Varshney, “Target localization in wireless sensor networks using error correcting codes,” IEEE Trans. Information Theory, vol. 60, no. 1, pp. 697–712, 2014.

[21] L. Wan, G. Han, L. Shu, S. Chan, and N. Feng, “Pd source diagnosis and localization in industrial high-voltage insulation system via multimodal joint sparse representation,” IEEE Trans. Ind. Electron., vol. 63, no. 4, pp. 2506–2516, 2016.

[22] T. Kamel, Y. Biletskiy, and L. Chang, “Fault diagnoses for

industrial grid-connected converters in the power distribution systems,” IEEE Trans. Ind. Electron., vol. 62, no. 10, pp. 6496– 6507, 2015.

[23] J. Lunze, Feedback control of large-scale systems. Prentice Hall Inc., Englewood Cliffs, NJ 07632, 1992.

[24] S. Gillijns and B. Moor, “Unbiased minimum-variance input and state estimation for linear discrete-time systems with direct feedthrough,” Automatica, vol. 43, pp. 934–937, 2007.