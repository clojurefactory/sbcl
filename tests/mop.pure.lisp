;;;; miscellaneous non-side-effectful tests of the MOP

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; While most of SBCL is derived from the CMU CL system, the test
;;;; files (like this one) were written from scratch after the fork
;;;; from CMU CL.
;;;;
;;;; This software is in the public domain and is provided with
;;;; absolutely no warranty. See the COPYING and CREDITS files for
;;;; more information.

;;;; Note that the MOP is not in an entirely supported state.
;;;; However, this seems a good a way as any of ensuring that we have
;;;; no regressions.

(assert (subtypep 'sb-mop:funcallable-standard-object 'standard-object))

(assert (find (find-class 'sb-mop:funcallable-standard-object)
              (sb-mop:class-direct-subclasses (find-class 'standard-object))))

(assert (find (find-class 'standard-object)
              (sb-mop:class-direct-superclasses
               (find-class 'sb-mop:funcallable-standard-object))))

(dolist (name '(sb-mop:generic-function
                sb-mop:method sb-mop:method-combination
                sb-mop:slot-definition sb-mop:specializer))
  (assert (find (find-class 'sb-mop:metaobject)
                (sb-mop:class-direct-superclasses (find-class name))))
  (assert (subtypep name 'sb-mop:metaobject)))

;;; No portable class Cp may inherit, by virtue of being a direct or
;;; indirect subclass of a specified class, any slot for which the
;;; name is a symbol accessible in the common-lisp-user package or
;;; exported by any package defined in the ANSI Common Lisp standard.
(let ((specified-class-names
       '(sb-mop:built-in-class
         sb-mop:class
         sb-mop:direct-slot-definition
         sb-mop:effective-slot-definition
         sb-mop:eql-specializer
         sb-mop:forward-referenced-class
         sb-mop:funcallable-standard-class
         sb-mop:funcallable-standard-object
         sb-mop:generic-function
         sb-mop:metaobject
         sb-mop:method
         sb-mop:method-combination
         sb-mop:slot-definition
         sb-mop:specializer
         sb-mop:standard-accessor-method
         sb-mop:standard-class
         sb-mop:standard-direct-slot-definition
         sb-mop:standard-effective-slot-definition
         sb-mop:standard-generic-function
         sb-mop:standard-method
         sb-mop:standard-object
         sb-mop:standard-reader-method
         sb-mop:standard-slot-definition
         sb-mop:standard-writer-method)))
  (labels ((slot-name-ok (name)
             (dolist (package (mapcar #'find-package
                                      '("CL" "CL-USER" "KEYWORD" "SB-MOP"))
                      t)
               (when (multiple-value-bind (symbol status)
                         (find-symbol (symbol-name name) package)
                       (and (eq symbol name)
                            (or (eq package (find-package "CL-USER"))
                                (eq status :external))))
                 (return nil))))
           (test-class-slots (class)
             (loop for slot in (sb-mop:class-slots class)
                   for slot-name = (sb-mop:slot-definition-name slot)
                   unless (slot-name-ok slot-name)
                   collect (cons class slot-name))))
    (loop for class-name in specified-class-names
          for class = (find-class class-name)
          for results = (test-class-slots class)
          when results do (cerror "continue" "~A" results))))

;;; AMOP says these are the defaults
(assert (equal (list (find-class 'standard-object))
               (sb-mop:class-direct-superclasses (make-instance 'standard-class))))
(assert (equal (list (find-class 'sb-mop:funcallable-standard-object))
               (sb-mop:class-direct-superclasses (make-instance 'sb-mop:funcallable-standard-class))))

(with-test (:name :bug-936513)
  ;; This used to fail as ENSURE-GENERIC-FUNCTION wanted a list specifying
  ;; the method combination, and didn't accept the actual object
  (let ((mc (sb-pcl:find-method-combination #'make-instance 'standard nil)))
    (ensure-generic-function 'make-instance :method-combination mc))
  ;; Let's make sure the list works too...
  (ensure-generic-function 'make-instance :method-combination '(standard)))

(with-test (:name :bug-309072)
  ;; original reported test cases
  (assert (raises-error? (make-instance 'sb-mop:slot-definition)
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:slot-definition :name 'pi)
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:slot-definition :name 3)
                         sb-pcl::slotd-initialization-type-error))
  ;; extra cases from the MOP dictionary
  (assert (raises-error? (make-instance 'sb-mop:slot-definition :name 'x
                                                                :initform nil)
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:slot-definition :name 'x
                                                                :initfunction (lambda () nil))
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:slot-definition :name 'x
                                                                :initfunction (lambda () nil))
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:slot-definition :name 'x
                                                                :allocation "")
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:slot-definition :name 'x
                                                                :initargs "")
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:slot-definition :name 'x
                                                                :initargs '(foo . bar))
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:slot-definition :name 'x
                                                                :initargs '(foo bar 3))
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:slot-definition :name 'x
                                                                :documentation '(()))
                         sb-pcl::slotd-initialization-error))
  ;; distinction between DIRECT- and EFFECTIVE- slot definitions
  (assert (raises-error? (make-instance 'sb-mop:effective-slot-definition
                                        :name 'x :readers '(foo))
                         sb-pcl::initarg-error))
  (assert (raises-error? (make-instance 'sb-mop:effective-slot-definition
                                        :name 'x :writers '(foo))
                         sb-pcl::initarg-error))
  (make-instance 'sb-mop:direct-slot-definition
                 :name 'x :readers '(foo))
  (make-instance 'sb-mop:direct-slot-definition
                 :name 'x :writers '(foo))
  (assert (raises-error? (make-instance 'sb-mop:direct-slot-definition
                                        :name 'x :readers "")
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:direct-slot-definition
                                        :name 'x :readers '(3))
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:direct-slot-definition
                                        :name 'x :readers '(foo . bar))
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:direct-slot-definition
                                        :name 'x :writers "")
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:direct-slot-definition
                                        :name 'x :writers '(3))
                         sb-pcl::slotd-initialization-error))
  (assert (raises-error? (make-instance 'sb-mop:direct-slot-definition
                                        :name 'x :writers '(foo . bar))
                         sb-pcl::slotd-initialization-error)))
