Sponsoring Socities:

Original Article

# Robust Detection of Stealthy FDIAs in CPS: A Unified Functional Observer-Wavelet Approach

Submission ID 18ab05e7-5561-4eef-994d-daecb254ba44

Manuscript ID draft-18ab05e7-5561-4eef-994d-daecb254ba44

Submission Version Initial Submission

PDF Generation 17 Jun 2026 03:18:40 EST by Atypon ReX

## Authors

Mr. Mahesh Kumar Nehra

Affiliations

the Department of Electrical Engineering, Indian Institute of Technology Jodhpur, Jodhpur 342030, India

Prof. Deepak Fulwani Corresponding Author Submitting Author

ORCiD

https://orcid.org/0000-0001-8881-783X

Affiliations

the Department of Electrical Engineering, Indian Institute of Technology Jodhpur, Jodhpur 342030, India

## Additional Information

Keywords

yy

## Files for peer review

p indicated; reviewers are able to access them online.

<table><tr><td>Name</td><td>Type of File</td><td>Size</td><td>Page</td></tr><tr><td>Robust_Detection_of_Stealthy_FDI As_in_CPS_A_Unified_Functional Observer_Wavelet_Approach_fina L172e.pd</td><td>Main Document - PDF</td><td>1.7 MB</td><td>Page 3</td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td></tr></table>

# Robust Detection of Stealthy FDIAs in CPS: A Unified Functional Observer-Wavelet Approach

Mahesh Kumar Nehra, Deepak Fulwani, Member, IEEE

Abstract—Stealthy false-data injection attacks (FDIAs) whose average energy remains below the measurement-noise floor can evade conventional residual-based detectors in cyber-physical systems, undermining integrity and safety. This paper proposes a unified functional observer (FO) and continuous wavelet transform (CWT) approach for detecting these attacks. The FO generates residuals that are sensitive to attacks; although their transients may be masked in the time domain, CWT-based time frequency analysis reveals localized energy bursts. A Lyapunov analysis guarantees closed-loop stability under observer-based mitigation, and dwell-time conditions provide robustness under switching. Simulations on a quadruple-tank system show reliable detection of stealthy attacks with low false-alarm rates, while the mitigation strategy preserves stability across all tested cases. By combining detection and mitigation within a single FO, the proposed method avoids separate detection and control modules and is suitable for resource-constrained industrial CPS.

Index Terms—Cyber-physical systems, continuous wavelet transform, false data injection attacks, functional observer, Lyapunov stability.

## I. INTRODUCTION

NCIDENTS targeting industrial infrastructure—including [ the 2015 Ukraine power grid attack [1] and the 2021 Colonial Pipeline ransomware event [2]—have highlighted the exposure of cyberphysical systems (CPS) to coordinated adversarial action. The safety and security challenges of Industrial CPSs under typical cyber-physical attacks are presented in [3]. Among these threats, stealthy false data injection attacks (FDIAs) are particularly damaging: an attacker corrupts sensor measurements or control signals in a way that preserves legitimate system behavior, evading conventional detection mechanisms while gradually degrading plant performance or driving it toward instability. Existing FDIA detection methods are commonly grouped into model-based, data-driven, and hybrid approaches, each with distinct advantages and limitations. Model-based techniques detect cyber-attacks by comparing measured outputs with model-predicted estimates, generating residuals that flag anomalous behavior. Kalman filters [4], [5] are optimal under Gaussian noise, functional observers [6] provide computational efficiency, Unknown Input Observers [7] improve robustness to disturbances, and slidingmode functional observers [8], [9] combine FO selectivity with sliding-mode robustness. Despite these advances, none of these methods explicitly address stealthy FDIAs, whose residual remains indistinguishable from measurement noise in the time domain, constituting a structural detection gap that motivates the present work. Data-driven approaches reduce reliance on explicit system models by learning features from nominal and attack data. Machine learning approaches including SVM [10], KNN [11], CNNLSTM [12] and hybrid approaches [13]− [15] demonstrate promising detection capabilities, however they require extensive training data and lack formal analytical detectability guarantees under arbitrary attacks.

To address these limitations, we propose the Functional Observer-Continuous Wavelet Transform (FO-CWT) framework that exploits CWT's multi-resolution time-frequency decomposition of FO residuals to reveal localized energy anomalies-features that remain concealed in the time domain. Detection and mitigation are unified within a single observer structure, ensuring rapid response with minimal computational overhead-a critical requirement for safety-critical CPS.

This paper makes the following key contributions:

•Establishes analytical detectability condition for stealthy FDIAs that evade conventional residual thresholds by revealing distinct signatures in the wavelet energy domain.

• Proposes a unified FO that simultaneously generates attack-sensitive residuals for CWT analysis and trusted state estimates for control reconfiguration, ensuring seamless transition from detection to mitigation.

• Establishes Lyapunov-based stability guarantees under bounded disturbances and FDIAs, leveraging input-tostate stability (ISS) for mitigation and dwell-time constraints for robust switching.

The rest of the paper is organized as follows. Section II introduces system model and problem formulation. Sections III and IV develop the FO-CWT detection method and the mitigation strategy, respectively. Section V provides the stability analysis, Section VI reports the simulation studies, and Section VII concludes the paper.

## II. SystEM ModEL And ProbLEM FormuLation

Consider a networked CPS in which the plant, sensors, and controller are communicating over a shared network. The plant dynamics are described by the continuous-time LTI system with process and measurement noise

$$
{ \dot { x } } ( t ) = A x ( t ) + B u ( t ) + \eta ( t ) ,\tag{1}
$$

$$
y ( t ) = C x ( t ) + v ( t ) ,\tag{2}
$$

where $\ b { x } ( t ) \ \in \mathbb { R } ^ { n }$ is state, $u ( t ) \in \mathbb { R } ^ { m }$ the control input, and $\ b { y } ( t ) \in \mathbb { R } ^ { p }$ is the measured output. The system matrices $A \ \in \ \mathring { \mathbb { R } } ^ { n \times n } , \ B \ \in \ \mathbb { R } ^ { n \times m }$ , and $C \in \mathbb { R } ^ { p \times n }$ are known, with (A, C) observable and $( A , B )$ stabilizable. Process and measurement noises satisfy $\eta ( t ) \sim \mathcal { N } ( 0 , Q )$ and $v ( t ) \sim \mathcal { N } ( 0 , R )$ , where $Q \in \mathbb { R } ^ { n \times n }$ with $Q \geq 0 , R \in \mathbb { R } ^ { p \times p }$ with $R > 0$ ,and $\mathbb { E } [ \eta ( t ) v ^ { \top } ( t ) ] = 0$ for all t.

Under a FDIA on the sensor-to-controller communication link, the received measurement is corrupted as

$$
y _ { a } ( t ) = y ( t ) + \beta ( t ) ,\tag{3}
$$

where $\beta ( t ) \ = \ \rho \odot \Gamma ( t ) \ \in \ \mathbb { R } ^ { p }$ denotes the injected attack signal, with  denoting the element-wise product, $\rho \in \mathbb { R } ^ { p }$ the channel-wise attack magnitudes and $\Gamma ( t ) \in \mathbb { R } ^ { p }$ the temporal profile such as constant bias, sinusoidal, ramp, or sparse burst. The attack is assumed bounded, $\| \beta ( t ) \| \le \beta _ { m a x }$ for some unknown constant $\beta _ { m a x } \ > \ 0 .$ , and becomes active at an unknown time instant $t _ { a } \geq 0 ,$ such that $\beta ( t ) = 0$ for $t < t _ { a }$

Definition 1 (Stealthy FDIA). Let β(t) denote a deterministic attack signal acting on the CPS over a time window of length $T > 0$ The attack is said to be stealthy if its average energy over the window T remains below the expected measurement noise power :

$$
\frac { 1 } { T } \int _ { t } ^ { t + T } \lVert \beta ( \tau ) \rVert ^ { 2 } d \tau \ < \mathbb { E } \big [ \lVert v ( t ) \rVert ^ { 2 } \big ] = \operatorname { t r } ( R )\tag{4}
$$

Under the assumption on the noise process v(t), the timeaverage $\begin{array} { r } { \frac { 1 } { T } \int _ { 0 } ^ { T } \lVert v ( \tau ) \rVert ^ { 2 } d \tau } \end{array}$ converges to the ensemble average $\mathbb { E } [ \| v ( t ) \| ^ { 2 } ] \ = \ \mathrm { t r } ( R )$ for large T, the left-hand side denotes the deterministic time-averaged attack energy.

Here, we take $T > T _ { \mathrm { s s } } ,$ with $T _ { \mathrm { s s } }$ is the settling time of the nominal closed-loop system, so that the energy comparison is made under steady-state conditions. This definition characterizes stealthy attacks capable of evading conventional residualbased detectors relying on magnitude thresholds or pre-specified anomaly patterns. The choice of T trades off detection latency against robustness to transient disturbances.

Problem Statement: Consider the networked industrial CPS in (1)(2), where sensor measurements can be corrupted by stealthy FDIAs as defined in (3) and satisfying Definition 1. The goal is to propose an observer-based framework that (i) detects such attacks via timefrequency analysis of the observer output and (ii) supports resilient control reconfiguration when the plant operates under compromised measurements.

## III. FO-CWT ATTACK DETECTION FRAMEWORK

The proposed FO-CWT architecture is illustrated in Fig. 1. Following the approach in [16], the functional state vector is defined as $z ( t ) = F x ( t )$ , where $F \in \mathbb { R } ^ { r \times n }$ specifies the targeted linear functions of the state. The FO is constructed as

$$
\dot { w } ( t ) = N w ( t ) + J y ( t ) + H u ( t ) ,\tag{5}
$$

$$
\hat { z } ( t ) = w ( t ) + E y ( t ) ,\tag{6}
$$

where $w ( t ) \in \mathbb { R } ^ { r }$ is the internal observer state and ${ \hat { z } } ( t ) \in$ Rr denotes the estimate of $z ( t )$ . The observer gain matrices $N , J , H$ , and E are chosen to ensure asymptotic convergence of $\hat { z } ( t ) \ \mathrm { t o } \ z ( t )$ under nominal conditions. The estimation error is defined as

$$
e ( t ) = z ( t ) - \hat { z } ( t ) = F x ( t ) - w ( t ) - E y ( t ) .\tag{7}
$$

<!-- image-->  
Fig. 1. Unified FOCWT detection and mitigation architecture within a network-controlled CPS.

Substituting (2) into (7) and applying the matching conditions derived in [16] together with (1) and (5), the error dynamics simplify to

$$
\dot { e } ( t ) = N e ( t ) - E \dot { v } ( t ) .\tag{8}
$$

In practical CPS implementations, sensor noise $v ( t )$ is typically band-limited due to finite sensor bandwidth and is therefore differentiable in the mean-square sense. Choosing N to be Hurwitz ensures (i) exponential convergence $e ( t ) \to 0$ in the absence of noise and (ii) mean-square boundedness of $e ( t )$ under process and measurement noise.

## A. Residual Characterization Under Sensor Attacks

The residual signal is defined as

$$
r ( t ) \triangleq z ( t ) - \hat { z } ( t ) = e ( t ) ,\tag{9}
$$

quantifying the deviation between the true functional state and its estimate. This residual serves as the primary indicator for anomaly detection. Substituting the attacked measurement $y _ { a } ( t )$ into the FO estimate z(t) yields

$$
\hat { z } ( t ) = w ( t ) + E y _ { a } ( t ) = w ( t ) + E C x ( t ) + E v ( t ) + E \beta ( t ) .\tag{10}
$$

The residual, defined in (9), becomes

$$
r ( t ) = ( F - E C ) x ( t ) - w ( t ) - E v ( t ) - E \beta ( t ) .\tag{11}
$$

Applying the FO matching condition $F = E C$

$$
r ( t ) = \underbrace { - w ( t ) } _ { \mathrm { O b s e r v e r ~ t r a n s i e n t ~ N o m i n a l ~ n o i s e ~ A t t a c k ~ s i g n a t u r e } } .\tag{12}
$$

Under attack-free operation, $\beta ( t ) = 0$ , residual becomes

$$
r ( t ) = - w ( t ) - E v ( t ) .\tag{13}
$$

Without attacks, $r ( t )$ depends only on bounded observer transient and measurement noise terms. Under attack, $E \beta ( t )$ causes the residual to deviate from its nominal behaviour.

For attacks satisfying Definition 1, the attack-induced deviations can remain concealed within the measurement noise floor. This limitation motivates the use of time-frequency analysis approach, as detailed in the next subsection.

## B. Time-Frequency Representation of FO Residuals

The CWT of $r ( t )$ is computed using a zero-mean, timelocalized mother wavelet $\psi _ { a , b } ( t )$ , with scales selected based on system eigenstructure [17], as detailed in Section III-C5.

$$
W _ { r } ( a , b ) = \int _ { - \infty } ^ { \infty } r ( t ) \psi _ { a , b } ^ { * } ( t ) d t\tag{14}
$$

where $W _ { r } ( a , b )$ denotes the wavelet coefficients of the residual $r ( t )$ , and $\begin{array} { r } { \psi _ { a , b } ( t ) ~ = ~ \frac { 1 } { \sqrt { a } } \psi \Bigl ( \frac { t - b } { a } \Bigr ) } \end{array}$ is a scaled and translated mother wavelet. Here, $a > 0$ denotes the scale and b the timeshift. The complex conjugate $\psi _ { a , b } ^ { * } ( t )$ ensures correct amplitude and phase representation for complex wavelets. The localized wavelet energy is then defined as

$$
E _ { r } ( a , b ) = | W _ { r } ( a , b ) | ^ { 2 }\tag{15}
$$

which quantifies the time-frequency concentration of the residual signal at scale a and time-shift b. While large FDIAs may be visible in raw residuals, the CWT framework excels at exposing stealthy attacks whose signatures are masked by process and measurement noise, enhancing detection sensitivity.

A variety of mother wavelets have been established in the literature, including Morlet, Haar, and Mexican Hat, each exhibiting distinct timefrequency localization properties. In this work, the Morlet wavelet is selected due to its optimal trade-off between time and frequency localization [18]. Following [19], the mother wavelet is defined as:

$$
\psi ( t ) = \pi ^ { - 1 / 4 } e ^ { i \omega t } e ^ { - t ^ { 2 } / 2 } , \mathrm { ~ w h e r e ~ } \omega _ { 0 } = 6\tag{16}
$$

To ensure a well-defined CWT, the residual $r ( t )$ has finite energy under bounded noise conditions. The mother wavelet ψ(t) satisfies the standard admissibility condition

$$
C _ { \psi } = \int _ { 0 } ^ { \infty } \frac { | \hat { \psi } ( \omega ) | ^ { 2 } } { \omega } d \omega < \infty ,\tag{17}
$$

where $C _ { \psi }$ is the admissibility constant that ensures energy conservation and wavelet invertibility [17]. $\hat { \psi } ( \omega )$ denotes the Fourier transform of $\psi ( t )$

## C. Wavelet Energy-Based Attack Detection Criterion

This subsection formalizes a wavelet energy-based detection criterion for stealthy FDIAs by mapping CWT energy into a scalar decision variable. The FO residual is decomposed into noise and attack components, and the sensitivity of CWT energy to localized perturbations is analyzed to establish the detectability conditions derived subsequently.

1) Equivalent Residual Representation: After the transient period, the FO estimation error decays exponentially. Let $t _ { s } ~ > ~ 0$ denote the settling time such that $\| e ( t ) \| \le \varepsilon _ { e }$ for all $t > t _ { s } ,$ ,where $\varepsilon _ { e } > 0$ is a small constant determined by the observer design. From (12), the residual contains the observer transient $w ( t )$ , noise $v ( t )$ and attack terms $\beta ( t )$ . To simplify the residual-domain representation, define

$$
\begin{array} { r } { \bar { v } ( t ) \triangleq E v ( t ) , \qquad \bar { \beta } ( t ) \triangleq E \beta ( t ) , } \end{array}\tag{18}
$$

where $\bar { \boldsymbol { v } } ( t ) , \bar { \boldsymbol { \beta } } ( t ) \in \mathbb { R } ^ { r }$ denote the noise and attack components, respectively, in the residual space. For $t \ > \ t _ { s } ,$ the

observer transient $w ( t )$ satisfies $\| w ( t ) \| \leq \varepsilon _ { e }$ and is therefore negligible. The residual in (12) can be approximated as

$$
\begin{array} { r } { r ( t ) \approx \bar { v } ( t ) + \bar { \beta } ( t ) , } \end{array}\tag{19}
$$

and, in the absence of attacks,

$$
r ( t ) \approx \bar { v } ( t ) .\tag{20}
$$

2) Noise Floor Characterization: To establish a reliable detection criterion, CWT energy under attack-free operation is first quantified. The following lemma characterizes the expected localized wavelet energy of the FO residual in the absence of attacks.

Lemma 1. (Wavelet-Domain Noise Floor). Consider the FO residual $r ( t )$ without attacks, as given by (20). Then, for all $t > t _ { s } ,$ the expected localized wavelet energy satisfies

$$
\mathbb { E } \left[ | W _ { r } ( a , b ) | ^ { 2 } \right] \leq \| \psi \| _ { 2 } ^ { 2 } \lambda _ { \operatorname* { m a x } } ( R _ { v } ) ,\tag{21}
$$

where $R _ { v } \ : = \ : \mathbb { E } [ \bar { v } ( t ) \bar { v } ^ { \top } ( t ) ] \ : = \ : E R E ^ { \top }$ , residual-space noise covariance.

Proof. Under attack-free operation, the equivalent residual reduces to $r ( t ) = \bar { v } ( t )$ since $\bar { \beta } ( t ) = 0$ , where $\bar { v } ( t ) \sim \mathcal { N } ( 0 , R _ { v } )$ represents the aggregated non-attack contribution in the residual space. Using (14), the expected wavelet energy becomes

$$
\mathbb { E } \left[ | W _ { r } ( a , b ) | ^ { 2 } \right] = \frac { 1 } { a } \mathbb { E } \left[ \left| \int _ { - \infty } ^ { \infty } \bar { v } ( t ) \psi ^ { * } \left( \frac { t - b } { a } \right) d t \right| ^ { 2 } \right] .
$$

Expanding the squared magnitude and applying the expectation operator:

$$
\mathbb { E } \big [ | W _ { r } ( a , b ) | ^ { 2 } \big ] = \frac { 1 } { a } \int _ { - \infty } ^ { \infty } \int _ { - \infty } ^ { \infty } \psi ^ { * } \bigg ( \frac { t - b } { a } \bigg ) \psi \bigg ( \frac { \tau - b } { a } \bigg )
$$

Since $\bar { v } ( t )$ remains zero-mean white Gaussian noise in the residual space, its autocorrelation satisfies

$$
\mathbb { E } [ \bar { v } ( t ) \bar { v } ^ { \top } ( \tau ) ] = R _ { v } \delta ( t - \tau ) ,
$$

where $\delta ( \cdot )$ is the Dirac delta function. $R _ { v }$ is the residual domain noise covariance, where $R _ { v } = E R E ^ { \top }$ transforms the measurement noise covariance R to the residual space.

Substituting this into the integral and applying the shifting property:

$$
\mathbb { E } \left[ | W _ { r } ( a , b ) | ^ { 2 } \right] \leq \frac { 1 } { a } \int _ { - \infty } ^ { \infty } \left| \psi \left( \frac { t - b } { a } \right) \right| ^ { 2 } \lambda _ { \operatorname* { m a x } } ( R _ { v } ) d t .
$$

where the inequality follows from the bound $\begin{array} { r l } { R _ { v } } & { { } \leq } \end{array}$ $\lambda _ { \operatorname* { m a x } } ( R _ { v } ) \mathbf { I }$ , which provides a conservative upper bound on the residual noise covariance. Applying the change of variables $\textstyle u \ = \ { \frac { t - b } { a } } , \ d t \ = \ a d u$ . Because the original limits are $t ~ \in ~ ( - \infty , \stackrel {  } { \infty } )$ and $a \ > \ 0$ in the CWT framework, the corresponding limits in u remain $( - \infty , \infty )$ . Therefore,

$$
{ \frac { 1 } { a } } \int _ { - \infty } ^ { \infty } \left| \psi \left( { \frac { t - b } { a } } \right) \right| ^ { 2 } d t = \int _ { - \infty } ^ { \infty } | \psi ( u ) | ^ { 2 } d u = \| \psi \| _ { 2 } ^ { 2 } .
$$

For all $t > t _ { s }$ where the observer transient has settled:

$$
\mathbb { E } \left[ | W _ { r } ( a , b ) | ^ { 2 } \right] \leq \| \psi \| _ { 2 } ^ { 2 } \lambda _ { \operatorname* { m a x } } ( R _ { v } ) ,
$$

The bound $\| \psi \| _ { 2 } ^ { 2 } \lambda _ { \operatorname* { m a x } } ( R _ { v } )$ is scale-independent, confirming that the nominal CWT noise floor remains uniform across all scales, determined solely by the wavelet energy $\| \psi \| _ { 2 } ^ { 2 }$ and the residual noise covariance $R _ { v }$

3) Detectability Conditions: The following theorem establish the detectability guarantee of the proposed framework.

Theorem 1 (CWT-Based Detectability of Stealthy FDIAs). Consider the FO residual under attack (19), with $W _ { r } ( a , b )$ computed using an admissible mother wavelet $\psi ( t )$ with $e f -$ fective passband $[ \omega _ { 1 } , \omega _ { 2 } ] .$ If the attack signal $\bar { \beta } ( t )$ has nonzero energy over a finite time interval $[ { t _ { a } } , { t _ { a } } + \Delta t ]$ and its spectral content overlaps with the effective passband of $\psi ( t )$ at some scale $a ^ { * }$ , then there exists at least one scale-time pair $( a ^ { * } , b ^ { * } )$ where $b ^ { * } \in \left[ t _ { a } , t _ { a } + \Delta t \right]$ ,such that

$$
\Delta E _ { r } ( a ^ { * } , b ^ { * } ) > 0 ,\tag{22}
$$

the expected localized wavelet energy increment is defined as

$$
\Delta E _ { r } ( a , b ) \triangleq \mathbb { E } \big [ | W _ { r } ( a , b ) | ^ { 2 } \big ] - \mathbb { E } \big [ | W _ { v } ( a , b ) | ^ { 2 } \big ] .\tag{23}
$$

Proof. By CWT linearity

$$
W _ { r } ( a , b ) = W _ { v } ( a , b ) + W _ { \beta } ( a , b ) .\tag{24}
$$

Taking expectations of $| W _ { r } ( a , b ) | ^ { 2 }$ and expanding, we obtain

$$
\begin{array} { r l } & { \mathbb { E } \big [ | W _ { r } ( a , b ) | ^ { 2 } \big ] = \mathbb { E } \big [ | W _ { v } ( a , b ) | ^ { 2 } \big ] + \mathbb { E } \big [ | W _ { \beta } ( a , b ) | ^ { 2 } \big ] } \\ & { \qquad + 2 \mathrm { R e } \big \{ \mathbb { E } [ W _ { v } ( a , b ) W _ { \beta } ^ { * } ( a , b ) ] \big \} . } \end{array}\tag{25}
$$

Since $\bar { v } ( t )$ and $\bar { \beta } ( t )$ are statistically independent and $\bar { v } ( t )$ is zero-mean, the cross-correlation term $\mathbb { E } [ W _ { v } ( a , b ) W _ { \beta } ^ { * } ( a , b ) ]$ vanishes. Hence, localized wavelet energy increment is

$$
\begin{array} { r l } & { \Delta E _ { r } ( a , b ) = \mathbb { E } \big [ | W _ { r } ( a , b ) | ^ { 2 } \big ] - \mathbb { E } \big [ | W _ { v } ( a , b ) | ^ { 2 } \big ] } \\ & { \qquad = \mathbb { E } \big [ | W _ { \beta } ( a , b ) | ^ { 2 } \big ] \geq 0 . } \end{array}\tag{26}
$$

establishing the non-negativity of the wavelet-domain energy increment. Since $\bar { \beta } ( t )$ has nonzero energy over $[ t _ { a } , t _ { a } + \Delta t ] \colon$

$$
\int _ { t _ { a } } ^ { t _ { a } + \Delta t } | \bar { \beta } ( t ) | ^ { 2 } d t = E _ { \beta } > 0 .\tag{27}
$$

By Parseval's theorem for the CWT (14), the signal energy is preserved in the wavelet domain:

$$
\int _ { - \infty } ^ { \infty } | \bar { \beta } ( t ) | ^ { 2 } d t = \frac { 1 } { C _ { \psi } } \int _ { 0 } ^ { \infty } \int _ { - \infty } ^ { \infty } | W _ { \beta } ( a , b ) | ^ { 2 } \frac { d b d a } { a ^ { 2 } } ,\tag{28}
$$

Because the attack signal $\bar { \beta } ( t )$ is time-localized within $[ { t _ { a } } , { t _ { a } } + \Delta t ]$ , the CWT coefficients attain significant magnitude only for translation parameters b within this interval. Hence, the wavelet energy is primarily concentrated in the region $\{ ( a , b ) : b \in [ t _ { a } , t _ { a } + \Delta t ] \}$ of the time-scale plane. From (27) we have

$$
E _ { \beta } = \int _ { t _ { a } } ^ { t _ { a } + \Delta t } | \bar { \beta } ( t ) | ^ { 2 } d t = \frac { 1 } { C _ { \psi } } \int _ { 0 } ^ { \infty } \int _ { t _ { a } } ^ { t _ { a } + \Delta t } | W _ { \beta } ( a , b ) | ^ { 2 } \frac { d b d a } { a ^ { 2 } } .\tag{29}
$$

Now, suppose by contradiction that $W _ { \beta } ( a , b ) = 0$ for all $( a , b )$ with $b \in [ t _ { a } , t _ { a } + \Delta t ]$ . Then the right-hand side of (29) equals zero, contradicting $E _ { \beta } > 0$ . Therefore, there exists $b ^ { * } \in$ $[ { t _ { a } } , { t _ { a } } + \Delta t ]$ and scale $a > 0$ such that $W _ { \beta } ( a , b ^ { * } ) \neq 0$

Since $\bar { \beta } ( t )$ spectrally overlaps with $[ \omega _ { 1 } , \omega _ { 2 } ]$ , there exists a $a ^ { * }$ such that

$$
\omega _ { 1 } \leq \frac { \omega _ { 0 } } { a ^ { * } } \leq \omega _ { 2 } ,\tag{30}
$$

where $\omega _ { 0 }$ is the center frequency of $\psi ( t )$ At this scale, the wavelet is sensitive to the attack's spectral signature, ensuring detectability. Consequently, $\Delta E _ { r } ( a ^ { * } , b ^ { * } ) =$ $\mathbb { E } \big [ | W _ { \beta } ( a ^ { * } , b ^ { * } ) | ^ { 2 } \big ] > 0$

This demonstrates that any stealthy FDIA that remains bounded in the time domain induces a strictly positive localized wavelet energy deviation in the time-frequency domain, rendering it detectable via FOCWT analysis.

4) CWT-Based Energy Statistic: Building on Theorem 1 and (14), we integrate the squared wavelet coefficients over a predefined scale-time region [19]. This integrated energy statistic captures the aggregate anomalous energy content while suppressing spatially diffuse noise distributed across the time—frequency plane. Let $S _ { \mathrm { s c a l e s } } = [ a _ { \mathrm { m i n } } , a _ { \mathrm { m a x } } ]$ denote the analysis scales chosen to capture the expected attack characteristics, and let $\mathcal { W } ( t ) = [ t - T _ { w } / 2 , t + T _ { w } / 2 ]$ represent a sliding time window of width $T _ { w }$ centered at time t. The integrated wavelet energy statistic is defined as follows.

$$
E _ { W } ( t ) = \frac { 1 } { C _ { \psi } } \int _ { a _ { \mathrm { m i n } } } ^ { a _ { \mathrm { m a x } } } \int _ { t - T _ { w } } ^ { t } \left| W _ { r } ( a , \tau ) \right| ^ { 2 } \frac { d \tau d a } { a ^ { 2 } }\tag{31}
$$

5) Practical Scale Selection: The scale range $S _ { \mathrm { s c a l e s } }$ is determined from the system's characteristic frequency spectrum, ensuring reliable detection over the system's operational bandwidth. Given the system matrix A with eigenvalue spectrum $\{ \lambda _ { 1 } , \lambda _ { 2 } , \ldots , \lambda _ { n } \}$ , the characteristic frequency $f _ { i }$ associated with each eigenvalue is extracted as:

$$
f _ { i } = { \left\{ \begin{array} { l l } { | \operatorname { I m } ( \lambda _ { i } ) | , } & { { \mathrm { i f ~ } } \lambda _ { i } = \sigma _ { i } \pm j \omega _ { i } { \mathrm { ~ } } ( \mathrm { c o m p l e x } ) , } \\ { | \operatorname { R e } ( \lambda _ { i } ) | , } & { { \mathrm { i f ~ } } \lambda _ { i } = \sigma _ { i } { \mathrm { ~ } } ( \mathrm { r e a l } ) } \end{array} \right. }\tag{32}
$$

where $| \operatorname { I m } ( \lambda _ { i } ) |$ represents the natural oscillation frequency for complex eigenvalues, and $| \operatorname { R e } ( \lambda _ { i } ) |$ represents the dominant decay rate, quantifying the transient response bandwidth for real eigenvalues. The frequency bounds are then established as:

$$
\omega _ { \mathrm { m a x } } = \operatorname* { m a x } \{ f _ { 1 } , \dots , f _ { n } \} , \omega _ { \mathrm { m i n } } = \operatorname* { m i n } \{ f _ { 1 } , \dots , f _ { n } \} .\tag{33}
$$

To capture attack signatures across a wide frequency range, we extend the analysis band by one decade beyond each boundary of the nominal system bandwidth:

$$
f _ { \mathrm { m i n } } = 0 . 1 \omega _ { \mathrm { m i n } } , \qquad f _ { \mathrm { m a x } } = 1 0 \omega _ { \mathrm { m a x } } .\tag{34}
$$

Using the Morlet wavelet scale—frequency relationship with center frequency $\hat { \psi } _ { 0 } ~ = ~ 6 ~ [ 1 9 ]$ , the corresponding Fourier wavelength is Λ ≈ 1.03s. The resulting scale bounds are:

$$
a _ { \mathrm { m i n } } = \frac { 0 . 6 } { \omega _ { \mathrm { m a x } } } , \qquad a _ { \mathrm { m a x } } = \frac { 6 0 } { \omega _ { \mathrm { m i n } } } .\tag{35}
$$

The scale interval is subsequently discretized logarithmically as [19]:

$$
S _ { \mathrm { s c a l e s } } = \{ a _ { j } = a _ { \mathrm { m i n } } 2 ^ { j \delta } : j = 0 , \ldots , J - 1 \} .\tag{36}
$$

Here, $\delta \approx 0 . 1 2 5 – 0 . 5$ sets the scale resolution, for typical CPS bandwidths spanning one to two decades, the choice gives roughly $J = 3 2 – 4 8$ scales.

6) Detection Threshold and Decision Rule: The threshold Θ is computed from attack-free baseline measurements. Following [20], [21], we define:

$$
\Theta = \left( 1 + \kappa \right) P _ { \varrho } \left( E _ { W } ^ { \mathrm { b a s e l i n e } } \right) ,\tag{37}
$$

where $P _ { \varrho } ( \cdot )$ is the o-th percentile of the baseline energy samples $\bar { E } _ { W } ^ { \mathrm { b a s e l i n e } } , \varrho$ sets the nominal false-alarm rate, and $\kappa \in ( 0 , 1 )$ is a safety margin against estimation uncertainty and operational transients. The detection decision at each time instant t, is:

$$
\begin{array} { r l } & { \mathcal { H } _ { 0 } : \ E _ { W } ( t ) \leq \Theta \qquad \mathrm { ( n o ~ a t t a c k ) } , } \\ & { \mathcal { H } _ { 1 } : \ E _ { W } ( t ) > \Theta \qquad \mathrm { ( a t t a c k ~ d e t e c t e d ) } . } \end{array}\tag{38}
$$

## D. Detection Algorithm

Algorithm 1 presents the real-time detection procedure, operates in two phases: an offline initialization phase that establishes baseline statistics from attack-free data, and an online detection phase that continuously monitors the integrated wavelet residual energy to identify attacks. The Algorithm incurs $\mathcal { O } ( r ^ { 2 } + N _ { a } N _ { t } )$ ≈ 900 operations per sample for typical parameters $( r \ = \ 2 , \ N _ { a } \ = \ 4 8 , \ N _ { t } \ = \ 3 0 )$ , comprising the FO update $[ \mathcal { O } ( r ^ { 2 } + r p + r m ) ]$ and the CWT computation $[ \mathcal { O } ( N _ { a } N _ { t } ) ]$ . This enables real-time deployment on resourceconstrained CPS.

Algorithm 1: Detection and Mitigation of Stealthy   
FDIAs   
1 Input: $r ( t ) , \psi _ { a , b } ( t ) , [ a _ { \mathrm { m i n } } , a _ { \mathrm { m a x } } ] , \kappa , T _ { w } , T _ { \mathrm { h o p } } .$   
2 Output: Detection flag  {0, 1}, detection time $t _ { d } .$   
3 Offline Baseline Characterization:   
4 Compute the nominal CWT coefficients $W _ { r } ( a , b )$ using (14),   
$t \in \mathsf { \bar { \rho } } [ 0 , T _ { \mathrm { b a s e l i n e } } ]$ , where $T _ { \mathrm { b a s e l i n e } } > 1 0 T _ { \mathrm { s s } } .$   
5 Compute Ew (t) from (31) and threshold Θ using (37).   
6 Online Monitoring:   
7 while system is operating do   
8 Acquire most recent r(t) over window $[ t - T _ { w } , t ] ;$   
9 Compute CWT coefficients: Wr(a, b) using (14);   
10 Compute Ew (t) from (31);   
11 if $\underline { { \hat { E _ { W } } ( t ) > \Theta } }$ then   
12 Attack detected: set flag ← 1;   
13 Detection time: $t _ { d } \gets t ;$ Trigger mitigation (39);   
14 return (1, t);   
15 else   
16 No attack: set flag $ 0 ;$   
17 end   
18 Slide window by $T _ { \mathrm { h o p } }$ and advance to next interval;   
19 end

## IV. OBSERVER-BASED MITIGATION UNDER FDIAS

Upon detection of an attack at time $t _ { d }$ via the decision rule (38), the mitigation protocol activates immediately (subject to dwell-time constraints from Section V-B) to prevent further propagation of corrupted data through the control loop. The mitigation procedure consists of three steps:

1) The potentially corrupted measurements $y _ { a } ( t )$ are no longer used for state estimation or control computation.

2) The FO estimate z(t) replaces the compromised controller output and is applied directly to the plant, i.e.,

$$
u ( t ) = \hat { z } ( t ) , \quad t \geq t _ { d } .\tag{39}
$$

3) To prevent propagation of contaminated states accumulated up to the detection instant $t _ { d } ,$ the FO internal state is reinitialized at the detection instant:

$$
w ( t _ { d } ^ { + } ) = \hat { z } ( t _ { d } ^ { - } ) - E y ( t _ { d } ) ,\tag{40}
$$

where $t _ { d } ^ { - }$ and $t _ { d } ^ { + }$ denote the time instants immediately before and after detection, respectively. This reinitialization ensures continuity in the FO output after switching.

## V. STABILITY ANALYSIS OF THE SWITCHED CPS

This section establishes Lyapunov-based Input-to-State Stability (ISS) of the closed-loop CPS under FO-driven mitigation, with dwell-time conditions ensuring robust switching between nominal and mitigation modes.

## A. Post-Detection Switched System Dynamics

Upon detection at $t = t _ { d }$ , the controller switches to (39), yielding the closed-loop dynamics

$$
{ \dot { x } } ( t ) = A x ( t ) + B { \hat { z } } ( t ) + \eta ( t ) , \quad t \geq t _ { d } .\tag{41}
$$

Using the FO relation $\hat { z } ( t ) = z ( t ) - e ( t ) = F x ( t ) - e ( t ) .$

$$
\dot { x } ( t ) = ( A + B F ) x ( t ) - B e ( t ) + \eta ( t ) ,\tag{42}
$$

where $A _ { c } = A + B F$ . From the FO design in Section III-A, the estimation error dynamics are governed by (8). For ISS analysis, these dynamics are equivalently expressed as

$$
\dot { e } ( t ) = N e ( t ) + d _ { e } ( t ) , \quad t \geq t _ { d } ,\tag{43}
$$

where $\begin{array} { r } { d _ { e } ( t ) = - E \dot { \boldsymbol { v } } ( t ) } \end{array}$ represents the contribution of bandlimited sensor noise. Combining the plant dynamics (42) and observer error dynamics (43) yields the augmented system

$$
\begin{array} { r } { \Big [ \dot { \boldsymbol { x } } ( t ) \Big ] = \left[ \begin{array} { l l } { \boldsymbol { A _ { c } } } & { - \boldsymbol { B } } \\ { \boldsymbol { 0 } } & { \boldsymbol { N } } \end{array} \right] \Big [ \boldsymbol { x } ( t ) \Big ] + \left[ \begin{array} { l l } { \boldsymbol { I _ { n } } } & { \boldsymbol { 0 } } \\ { \boldsymbol { 0 } } & { \boldsymbol { I _ { r } } } \end{array} \right] \Big [ \boldsymbol { \eta } ( t ) \Big ] , } \end{array}\tag{44}
$$

compactly,

$$
\dot { \xi } ( t ) = A _ { \mathrm { a u g } } \xi ( t ) + B d ( t ) , \qquad t \geq t _ { d } ,\tag{45}
$$

where

$$
\begin{array} { r l r } & { } & { \xi ( t ) = \left[ x ( t ) \right] , \quad A _ { \mathrm { a u g } } = \left[ A _ { c } \quad - B \right] , } \\ & { } & { \beta = \left[ I _ { n } \quad 0 \right] , \quad d ( t ) = \left[ \eta ( t ) \right] . } \\ & { } & { \quad B = \left[ 0 \quad I _ { r } \right] , \quad d ( t ) = \left[ d _ { e } ( t ) \right] . } \end{array}\tag{46}
$$

Assumption 1 (Bounded Disturbances). The aggregated disturbance vector d(t) satisfies:

$$
\| d ( t ) \| \leq \bar { d } < \infty , \quad \forall t \geq t _ { d } .\tag{47}
$$

where $\bar { d } > 0$ is a known constant. This bound is satisfied when process noise and sensor noise derivative are bounded.

Theorem 2 (ISS Under FO based mitigation). Suppose $A _ { a u g }$ is Hurwitz and Assumption 1 holds. Then the closed-loop CPS under FO-based mitigation is Input-to-State Stable (ISS) with respect to d(t) for $t \geq t _ { d }$ There exist positive constants $c _ { 1 } , c _ { 2 } , \lambda$ such that

$$
\| \xi ( t ) \| \leq c _ { 1 } e ^ { - \lambda ( t - t _ { d } ) } \| \xi ( t _ { d } ) \| + c _ { 2 } \operatorname* { s u p } _ { \tau \in [ t _ { d } , t ] } \| d ( \tau ) \| , \quad \forall t \geq t _ { d } ,
$$

and consequently,

$$
\operatorname* { l i m } _ { t \to \infty } \| \xi ( t ) \| \leq c _ { 2 } \bar { d } .\tag{48}
$$

Proof. Consider the augmented post-detection dynamics given by (45). Let the quadratic Lyapunov function be

$$
V ( \xi ) = \xi ^ { \top } P \xi , \qquad P = P ^ { \top } > 0 ,\tag{49}
$$

where P satisfies the Lyapunov equation

$$
A _ { \mathrm { a u g } } ^ { \top } P + P A _ { \mathrm { a u g } } = - Q _ { L } , \qquad Q _ { L } = Q _ { L } ^ { \top } > 0 .\tag{50}
$$

Differentiating $V ( \xi )$ along the trajectories of the augmented system and by using the inequality 2pq $\leq \varepsilon p ^ { 2 } + { \textstyle { \frac { 1 } { \varepsilon } } } q ^ { 2 }$ with $\varepsilon < \lambda _ { \mathrm { m i n } } ( Q _ { L } )$

$$
\dot { V } \leq - \alpha \| \xi \| ^ { 2 } + \gamma \| d ( t ) \| ^ { 2 } ,\tag{51}
$$

where $\alpha ~ = ~ \lambda _ { \mathrm { m i n } } ( Q _ { L } ) ~ - ~ \varepsilon$ and $\begin{array} { r } { \gamma \ = \ \frac { \| P B \| ^ { 2 } } { \varepsilon } } \end{array}$ are positive constants. Inequality (51) satisfies the ISSLyapunov condition, implying exponential decay of ξ(t) in the absence of disturbances and boundedness otherwise. Integrating (51) from $t _ { d }$ to t gives

$$
V ( \xi ( t ) ) \leq e ^ { - 2 \lambda ( t - t _ { d } ) } V ( \xi ( t _ { d } ) ) + \frac { \gamma } { \alpha } \operatorname* { s u p } _ { \tau \in [ t _ { d } , t ] } \| d ( \tau ) \| ^ { 2 } ,\tag{52}
$$

where $\begin{array} { r } { \begin{array} { c c l } { \lambda } & { = } & { \frac { \alpha } { 2 \lambda _ { \mathrm { m a x } } ( P ) } } \end{array} } \end{array}$ . Using $\begin{array} { r } { \lambda _ { \operatorname* { m i n } } ( P ) \lvert \lvert \xi \rvert \rvert ^ { 2 } \ \leq \ V ( \xi ) \ \leq } \end{array}$ $\lambda _ { \operatorname* { m a x } } ( P ) \Vert \xi \Vert ^ { 2 }$ and taking square roots of (52) yields

$$
\| \xi ( t ) \| \le c _ { 1 } e ^ { - \lambda ( t - t _ { d } ) } \| \xi ( t _ { d } ) \| + c _ { 2 } \operatorname* { s u p } _ { \tau \in [ t _ { d } , t ] } \| d ( \tau ) \| ,\tag{53}
$$

with $c _ { 1 } = \sqrt { \frac { \lambda _ { \operatorname* { m a x } } ( P ) } { \lambda _ { \operatorname* { m i n } } ( P ) } }$ and $\begin{array} { r } { c _ { 2 } = \sqrt { \frac { \gamma \lambda _ { \operatorname* { m a x } } ( P ) } { \alpha \lambda _ { \operatorname* { m i n } } ( P ) } } . } \end{array}$ Since $d ( t )$ is bounded by ¯, taking the limit as $t \to \infty$ gives

$$
\operatorname* { l i m } _ { t \to \infty } \| \xi ( t ) \| \leq c _ { 2 } \bar { d } .\tag{54}
$$

Hence, the post-detection augmented system is Input-to-State Stable with respect to bounded disturbance input $d ( t )$

## B. Stability Under Dwell-Time Switching

Both the nominal and FO-based controllers are individually stable; however, rapid switching may induce transient instability. To prevent this, a minimum dwell-time constraint is imposed on the switching signal, $\sigma ( t ) \in \{ 1 , 2 \}$ , where each mode corresponds to the nominal or FO-based controller.

Definition 2 (Average Dwell Time [22]). The switching signal $\sigma ( t )$ is said to satisfy an average dwell-time condition if there exist constants $M _ { 0 } \geq 0$ and $T _ { d } > 0$ such that for all $t \geq t _ { 0 } ,$

$$
M _ { \sigma } ( t , t _ { 0 } ) \leq M _ { 0 } + \frac { t - t _ { 0 } } { T _ { d } } ,\tag{55}
$$

where $M _ { \sigma } ( t , t _ { 0 } )$ denotes the number of switches of $\sigma ( t )$ in the interval $[ t _ { 0 } , t ] .$

The dwell-time constraint (55) ensures ISS preservation under switching [23] by preventing Zeno behavior. In practice, $T _ { d } \approx 3  – 5 \tau _ { \mathrm { o b s } }$ suffices for transient decay [22]. Here $\tau _ { \mathrm { o b s } }$ denotes the FO time constant, determined by the least stable eigenvalue of the Hurwitz matrix N.

## VI. SIMULATION STUDIES

## A. System Description and Attack Scenarios

The proposed framework is validated using the quadrupletank process [24], a fourth-order LTI system with two control inputs and two measured outputs $( h _ { 1 } , h _ { 2 } )$ , linearized around a nominal operating point. Zero-mean Gaussian noise $( \sigma = 0 . 1 5 \mathrm { c m ) }$ emulates realistic sensor conditions. Two attack scenarios are considered: (i) A sinusoidal false data injection signal $\beta _ { 1 } ( t ) = \beta _ { \mathrm { m a x } } \sin ( 2 \pi \cdot 0 . 1 5 \cdot t ) , t \in [ 5 0 , 1 0 0 ]$ s is injected on Sensor 1, where attack amplitude $\beta _ { \mathrm { m a x } } = \mu \sqrt { \mathrm { t r } ( R ) }$ and $\mu > 0$ denotes the attack strength normalized by the noise floor. (ii) A composite attack signal $\beta _ { 2 } ( t )$ , constructed as a linearly ramping envelope with superimposed exponential growth and multi-sinusoidal modulation, is injected on Sensor 2 over $t \in [ 1 3 0 , 1 7 0 ] \mathrm { s }$

## B. Detection Performance

Figure 2 shows detection at $\mu \ = \ 1 . 0$ , where the attack amplitude equals the noise floor. The FO residual $r _ { F O }$ remains below $\Theta _ { \mathrm { F O } }$ throughout both attack windows, the attack therefore goes undetected by the conventional residual-based detection. The CWT energy $E _ { W } ( t )$ exceeds $\Theta _ { \mathrm { C W T } } .$ separating nominal and attack regimes. With $\Theta _ { \mathrm { C W T } } ~ = ~ 1 . 2$ (Sensor 1) and 1.15 (Sensor 2), the DR reaches 93.0% and 67.0%, respectively. The \~ 4 s detection delay arises from the sliding window width $T _ { w } = 3 \mathrm { s }$ and $T _ { \mathrm { h o p } } = 0 . 5 \ : \mathrm { s }$ ,which is negligible for CPS with slow dynamics.

## C. Mitigation Performance and Closed-Loop Stability

Upon detection, the mitigation protocol (39) activates at $t _ { d } \approx 5 3 \mathrm { ~ s ~ }$ (Sensor1) and $t _ { d } \approx 1 3 4 \mathrm { ~ s ~ }$ (Sensor 2). Figure 3 shows bounded state trajectories with smooth post-mitigation convergence, consistent with Theorem 2. Figure 4 gives the ROC curves across multiple attack strengths. At $\mu = 1 . 0 , \mathrm { F O - }$ CWT achieves an area under the curve (AUC) of 0.918 versus 0.263 for FO alone, a 249.5% improvement. At higher attack strengths, relative AUC gains range from 63.5% to 249.5%, with FOCWT outperforming FO alone throughout.

## VII. CONCLUSION

This paper presents a unified FO-CWT framework for detecting and mitigating stealthy FDIAs in CPS. By exploiting time—frequency localization of residual energy, the framework exposes low-magnitude attacks that evade threshold-based detection. Theoretical contributions include detectability conditions, Lyapunov-based ISS guarantees, and a unified observer architecture that enables simultaneous attack detection and control reconfiguration with minimal computational overhead. Simulation on the quadruple-tank system validate frame-work effectiveness. It achieves an AUC of 0.918, while preserving close loop stability. Future work includes extending to nonlinear systems, developing dual-observer architectures, adaptive wavelet selection, and hardware-in-the-loop validation.

<!-- image-->

<!-- image-->

<!-- image-->

<!-- image-->  
Fig. 2. Detection performance under stealthy FDIAs (µ = 1.0).

<!-- image-->

<!-- image-->

<!-- image-->  
Fig. 3. Mitigation performance under multi-sensor attacks.

## REFERENCES

[1] G. Liang, S. R. Weller, J. Zhao, F. Luo, and Z. Y. Dong, "The 2015 ukraine blackout: Implications for false data injection attacks," IEEE Trans. Power Syst., vol. 32, no. 4, pp. 33173318, 2017.

[2] T. Olorunlana and H. Mohammed, "Analysis of the colonial pipeline cybersecurity incident," Int. J. Sci. Archit. Technol. Environ., vol. 02, pp. 913, 2025.

[3] Y. Jiang, S. Wu, R. Ma, M. Liu, H. Luo, and O. Kaynak, "Monitoring and defense of industrial cyber-physical systems under typical attacks: From a systems and control perspective," IEEE Transactions on Industrial Cyber-Physical Systems, vol. PP, pp. 116, 01 2023.

<!-- image-->

[4] H. Fawzi, P. Tabuada, and S. Diggavi, "Secure estimation and control for cyber-physical systems under adversarial attacks," IEEE Trans. Autom. Control, vol. 59, no. 6, pp. 14541467, 2014.

[5] M. N. Kurt, Y. Yilmaz, and X. Wang, "Distributed quickest detection of cyber-attacks in smart grid," IEEE Trans. Inf. Forensics Security, vol. 13, no. 8, pp. 20152030, 2018.

[6] M. Kachhwaha, H. Modi, M. K. Nehra, and D. Fulwani, "Resilient control of dc microgrids against cyber attacks: A functional observer based approach," IEEE Trans. Power Electron., vol. 39, no. 1, pp. 459 468, 2024.

[7] M. Liu, C. Zhao, R. Deng, P. Cheng, and J. Chen, "False data injection attacks and the distributed countermeasure in dc microgrids," IEEE Trans. Control Netw. Syst., vol. 9, no. 4, pp. 19621974, 2022.

[8] T. Fernando, V. Sreeram, and B. Bandyopadhyay, "Sliding mode functional observers," in Proc. 10th Int. Conf. Control, Autom., Robot. Vis. (ICARCV), Hanoi, Vietnam, Dec. 2008, pp. 10121016.

[9] M. Kachhwaha, H. Modi, M. K. Nehra, and D. Fulwani, "Robust observer-based defense strategy against actuator and sensor cyber-attacks in dcmgs," IEEE Trans. Ind. Informat., vol. 20, no. 10, pp. 11 687 11696, 2024.

<!-- image-->

<!-- image-->

<!-- image-->

<!-- image-->  
FO FO-CWT  
Fig. 4. Comparison of ROC curves for FO and FO-CWT

[10] Y. Mo and B. Sinopoli, "False data injection attacks in control systems," IFAC Proc. Volumes, vol. 44, no. 1, pp. 58075812, 2011, iFAC World Congress.

[11] B. Genge, C. Haller, and I. Kiss, "A survey on security in cyber-physical systems: Issues, challenges and solutions," Computers & Electrical Engineering, vol. 53, pp. 1735, 2016.

[12] Z. Li, Y. Xie, R. Ma, and Z. Wei, "Optimizing cnn-lstm for the localization of false data injection attacks in power systems," Applied Sciences, vol. 14, no. 16, 2024.

[13] A. M. Abu-Nassar and W. G. Morsi, "Early detection of cyber-physical attacks on electric vehicles fast charging stations using wavelets and deep learning," IEEE Trans. Ind. Cyber-Phys. Syst., vol. 2, pp. 220 231, 2024.

[14] A. A. Nassar and W. Morsi, "Detection of cyber-attacks and power disturbances in smart digital substations using continuous wavelet transform and convolution neural networks," Electric Power Systems Research, vol. 229, p. 110157, 2024.

[15] H. N. Monday, J. P. Li, G. U. Nneji, A. Z. Yutra, B. D. Lemessa, S. Nahar, E. C. James, and A. U. Haq, "The capability of wavelet convolutional neural network for detecting cyber attack of distributed denial of service in smart grid," in ICCWAMTIP, 2021, pp. 413418.

[16] H. Trinh and T. Fernando, Functional Observers for Dynamical Systems. Berlin, Germany: Springer, 2012.

[17] P. S. Addison, The Illustrated Wavelet Transform Handbook: Introductory Theory and Applications in Science, Engineering, Medicine and Finance, 2nd ed. CRC Press, 2017.

[18] S. Mallat, A Wavelet Tour of Signal Processing, Third Edition: The Sparse Way, 3rd ed. USA: Academic Press, Inc., 2008.

[19] C. Torrence and G. P. Compo, "A practical guide to wavelet analysis," Bulletin of the American Meteorological Society, vol. 79, no. 1, pp. 61 78, 1998.

[20] M. Basseville and I. Nikiforov, Detection of Abrupt Change Theory and Application. PTR Prentice-Hall, 04 1993, vol. 15.

[21] D. C. Montgomery, Introduction to Statistical Quality Control, 7th ed. Hoboken, NJ: Wiley, 2009.

[22] J. Hespanha and A. Morse, "Stability of switched systems with average dwell-time," in Proc. 38th IEEE Conf. Decis. Control (CDC), vol. 3, 1999, pp. 26552660.

[23] D. Liberzon, Switching in Systems and Control. Birkhäuser Boston, MA, USA, 2003.

[24] K. Johansson, "The quadruple-tank process: a multivariable laboratory process with an adjustable zero," IEEE Trans. Control Syst. Technol., vol. 8, no. 3, pp. 456465, 2000.

<!-- image-->

Mahesh Kumar Nehra received the B.E. degree in Electronics and Communication Engineering from University of Rajasthan, Jaipur, India, and the MTech. degree in Dynamics and Control from the Indian Institute of Technology, Bombay, Mumbai, India, in 2007 and 2017, respectively. He is currently working toward the Ph.D. degree in control systems with the Department of Electrical Engineering, Indian Institute of Technology Jodhpur, Jodhpur, India. He has more than 17 years of experience in Communication, Electronic Warfare, Flight control,

and Navigation systems of aircraft. His research interests include the Security of cyber-physical systems using control theory, Optimal Control, and Robust Control.

<!-- image-->

Deepak Fulwani (Member, IEEE) received the Ph.D. degree in control systems from the Indian Institute of Technology (IIT) Bombay, Mumbai, India, in 2009. He was an assistant professor at IIT Guwahati, Guwahati, India, and served as a visiting faculty at IT Kharagpur, Kharagpur, India. He is currently a professor with the Department of Electrical Engineering, IIT Jodhpur, Jodhpur, India. He has authored or coauthored several articles in reputed international journals and conferences. His current research interests are power electronics, microgrids, and control systems. Dr. Fulwani was a guest associate editor for a special issue on structured DC microgrids for the IEEE Journal of Emerging and Selected Topics in Power Electronics in 2017. He was an associate editor for IEEE Transactions on Industry Applications from 2019 to 2022. He is currently an Editorial Board Member of Nature Scientific Reports and Associate Editor of IEEE Transactions on Industrial Electronics since June 2024. He was the recipient of the Excellence Award for his Ph.D. thesis work in the IDP program in Systems and Control in the 48th Convocation of IIT Bombay.