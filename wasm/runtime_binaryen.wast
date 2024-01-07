(module
  (type $float (struct (field (mut f64))))
  (type $string (array (mut i8)))
  (type $array (array (mut (ref eq))))
  (type $floatarray (array (mut f64)))
  (type $gen_block (array (mut (ref eq))))
  (import "exn_tag" "exc" (tag $exc (param (ref eq))))

  ;; ==========
  ;; Exceptions
  ;; ==========

  (global $index_out_of_bound_string (ref $string)
     (array.new_fixed $string
       (i32.const 105)(i32.const 110)(i32.const 100)(i32.const 101)(i32.const 120)
       (i32.const 32)(i32.const 111)(i32.const 117)(i32.const 116)(i32.const 32)
       (i32.const 111)(i32.const 102)(i32.const 32)(i32.const 98)(i32.const 111)
       (i32.const 117)(i32.const 110)(i32.const 100)(i32.const 115)))

  ;; TODO exceptions
  (global (export "caml_exn_Match_failure") (ref eq)
       (array.new_fixed $gen_block
       (ref.i31 (i32.const 248))
       (array.new_fixed $string (i32.const 78) (i32.const 78) (i32.const 78))
       (ref.i31 (i32.const 0))))
  (global (export "caml_exn_Assert_failure") (ref eq)
       (array.new_fixed $gen_block
       (ref.i31 (i32.const 248))
       (array.new_fixed $string (i32.const 78) (i32.const 78) (i32.const 78))
       (ref.i31 (i32.const 1))))
  (global $invalid_argument (export "caml_exn_Invalid_argument") (ref eq)
       (array.new_fixed $gen_block
       (ref.i31 (i32.const 248))
       (array.new_fixed $string (i32.const 78) (i32.const 78) (i32.const 78))
       (ref.i31 (i32.const 2))))
  (global (export "caml_exn_Failure") (ref eq)
       (array.new_fixed $gen_block
       (ref.i31 (i32.const 248))
       (array.new_fixed $string (i32.const 78) (i32.const 78) (i32.const 78))
       (ref.i31 (i32.const 3))))
  (global (export "caml_exn_Not_found") (ref eq)
     (array.new_fixed $gen_block
       (ref.i31 (i32.const 248))
       (array.new_fixed $string (i32.const 78) (i32.const 78) (i32.const 78))
       (ref.i31 (i32.const 4))))

  (global (export "caml_exn_Out_of_memory") (ref eq) (ref.i31 (i32.const 5)))
  (global (export "caml_exn_Stack_overflow") (ref eq) (ref.i31 (i32.const 6)))
  (global (export "caml_exn_Sys_error") (ref eq) (ref.i31 (i32.const 7)))
  (global (export "caml_exn_End_of_file") (ref eq) (ref.i31 (i32.const 8)))
  (global (export "caml_exn_Division_by_zero") (ref eq) (ref.i31 (i32.const 9)))
  (global (export "caml_exn_Sys_blocked_io") (ref eq) (ref.i31 (i32.const 10)))
  (global (export "caml_exn_Undefined_recursive_module") (ref eq) (ref.i31 (i32.const 11)))

  ;; =========
  ;; functions
  ;; =========

  (func (export "compare_ints") (param $a (ref eq)) (param $b (ref eq)) (result (ref i31))
    (local $a' i32) (local $b' i32)
    (local.set $a' (i31.get_s (ref.cast (ref i31) (local.get $a))))
    (local.set $b' (i31.get_s (ref.cast (ref i31) (local.get $b))))
    (ref.i31
      (i32.sub
        (i32.gt_s (local.get $a') (local.get $b'))
        (i32.lt_s (local.get $a') (local.get $b'))))
  )

  (func (export "compare_floats") (param $a (ref eq)) (param $b (ref eq)) (result (ref i31))
    (local $a' f64) (local $b' f64)
    (local.set $a' (struct.get $float 0 (ref.cast $float (local.get $a))))
    (local.set $b' (struct.get $float 0 (ref.cast $float (local.get $b))))
    (ref.i31
      (i32.add
        (i32.sub
          (f64.gt (local.get $a') (local.get $b'))
          (f64.lt (local.get $a') (local.get $b')))
        (i32.sub
          (f64.eq (local.get $a') (local.get $a'))
          (f64.eq (local.get $b') (local.get $b'))))))

  ;; ======
  ;; Arrays
  ;; ======

  (func $array_length (export "array_length") (param $arr (ref eq)) (result (ref eq))
    (ref.i31 (array.len $floatarray
      (block $floatarray (result (ref $floatarray))
        (return (ref.i31 (array.len $array (ref.cast $array
          (br_on_cast $floatarray (ref eq) (ref $floatarray) (local.get $arr))))))
        )))
  )

  ;; (func $array_get_float_safe (param $arr (ref $floatarray)) (param $field (ref eq)) (result (ref $float))
  ;;   ;; TODO exceptions
  ;;   (struct.new_canon $float
  ;;     (array.get $floatarray
  ;;       (local.get $arr)
  ;;       (i31.get_s (ref.cast (ref i31) (local.get $field)))))
  ;; )

  ;; (func (export "array_get_float_safe") (param $arr (ref eq)) (param $field (ref eq)) (result (ref eq))
  ;;   (call $array_get_float_safe
  ;;     (ref.cast $floatarray (local.get $arr))
  ;;     (local.get $field)))

  ;; (func $array_get_int_or_addr_safe (param $arr (ref $array)) (param $field (ref eq)) (result (ref eq))
  ;;   ;; TODO exceptions
  ;;   (array.get $array
  ;;     (local.get $arr)
  ;;     (i31.get_s (ref.cast (ref i31) (local.get $field))))
  ;; )

  ;; (func (export "array_get_int_or_addr_safe") (param $arr (ref eq)) (param $field (ref eq)) (result (ref eq))
  ;;   (call $array_get_int_or_addr_safe (ref.cast $array (local.get $arr)) (local.get $field)))

  ;; (func $array_get_safe (param $arr (ref eq)) (param $field (ref eq)) (result (ref eq))
  ;;   (return
  ;;     (call $array_get_float_safe
  ;;       (block $floatarray (result (ref $floatarray))
  ;;         (br_on_cast $floatarray $floatarray (local.get $arr))
  ;;         (return (call $array_get_int_or_addr_safe (ref.cast $array) (local.get $field))))
  ;;       (local.get $field)))
  ;; )

  (func $array_get_safe (export "array_get_safe") (param (ref eq)) (param (ref eq)) (result (ref eq))
    (unreachable)
  )

  (func $array_set_unsafe (export "array_set_unsafe") (param (ref eq)) (param (ref eq)) (param (ref eq)) (result (ref eq))
    (unreachable)
  )

  (func $array_get_unsafe (export "array_get_unsafe") (param (ref eq)) (param (ref eq)) (result (ref eq))
    (unreachable)
  )

  ;; (func $array_set_float_unsafe (param $arr (ref $floatarray)) (param $field (ref eq))
  ;;                               (param $value (ref eq)) (result (ref eq))
  ;;     (array.set $floatarray
  ;;       (local.get $arr)
  ;;       (i31.get_s (ref.cast (ref i31) (local.get $field)))
  ;;       (struct.get $float 0 (ref.cast $float (local.get $value))))
  ;;     (ref.i31 (i32.const 0))
  ;; )

  ;; (func $array_set_int_or_addr_unsafe (param $arr (ref $array)) (param $field (ref eq))
  ;;                                     (param $value (ref eq)) (result (ref eq))
  ;;     (array.set $array
  ;;       (local.get $arr)
  ;;       (i31.get_s (ref.cast (ref i31) (local.get $field)))
  ;;       (local.get $value))
  ;;     (ref.i31 (i32.const 0))
  ;; )

  ;; (func $array_set_unsafe (export "array_set_unsafe")
  ;;                         (param $arr (ref eq)) (param $field (ref eq))
  ;;                         (param $value (ref eq)) (result (ref eq))
  ;;   (return
  ;;     (call $array_set_float_unsafe
  ;;       (block $floatarray (result (ref $floatarray))
  ;;         (br_on_cast $floatarray $floatarray (local.get $arr))
  ;;         (return
  ;;           (call $array_set_int_or_addr_unsafe
  ;;             (ref.cast $array) (local.get $field) (local.get $value))))
  ;;       (local.get $field)
  ;;       (local.get $value)
  ;;     ))
  ;; )

  ;; (func (export "array_set_safe")
  ;;                         (param $arr (ref eq)) (param $field (ref eq))
  ;;                         (param $value (ref eq)) (result (ref eq))
  ;;   ;; TODO exceptions
  ;;   (call $array_set_unsafe (local.get $arr) (local.get $field) (local.get $value))
  ;; )

  ;; ============
  ;; String/Bytes
  ;; ============

  ;; (func (export "bytes_set") (param $arr (ref eq)) (param $field (ref eq))
  ;;                            (param $value (ref eq)) (result (ref eq))
  ;;     ;; TODO exceptions
  ;;     (array.set $string
  ;;       (ref.cast $string (local.get $arr))
  ;;       (i31.get_s (ref.cast (ref i31) (local.get $field)))
  ;;       (i31.get_s (ref.cast (ref i31) (local.get $value))))
  ;;     (ref.i31 (i32.const 0))
  ;; )

  (func (export "string_get") (param $arr (ref eq)) (param $field_i31 (ref eq))
                              (result (ref eq))
      (local $field i32)
      (local.set $field (i31.get_s (ref.cast (ref i31) (local.get $field_i31))))
      (if (result (ref i31))
        (i32.lt_s (local.get $field) (array.len (ref.cast $string (local.get $arr))))
        (then
          (ref.i31
            (array.get_s $string
              (ref.cast $string (local.get $arr))
              (local.get $field))))
        (else
          (throw $exc
            (array.new_fixed $gen_block
              (ref.i31 (i32.const 0))
              (global.get $invalid_argument)
              (global.get $index_out_of_bound_string)))))
  )

  (func $string_eq (param $a (ref $string)) (param $b (ref $string)) (result i32)
    (local $len_a i32)
    (local $len_b i32)
    (local $pos i32)
    (local.set $len_a (array.len (local.get $a)))
    (local.set $len_b (array.len (local.get $b)))
    (if (i32.ne (local.get $len_a) (local.get $len_b))
        (then (return (i32.const 0)))
        (else (nop)))
    (local.set $pos (i32.const 0))
    (loop $next_char
      (if (i32.eq (local.get $len_a) (local.get $pos))
        (then (return (i32.const 1)))
        (else (nop)))
      (if (i32.ne (array.get_s $string (local.get $a) (local.get $pos))
                  (array.get_s $string (local.get $b) (local.get $pos)))
        (then (return (i32.const 0)))
        (else
          (local.set $pos (i32.add (i32.const 1) (local.get $pos)))
          (br $next_char))))
    (unreachable)
  )

  (func (export "string_eq") (param $a (ref eq)) (param $b (ref eq)) (result (ref eq))
    (ref.i31
      (call $string_eq (ref.cast $string (local.get $a)) (ref.cast $string (local.get $b))))
  )

  ;; ==========
  ;; Undefineds
  ;; ==========

  (func (export "unimplemented_1") (param (ref eq)) (result (ref eq))
    (unreachable))

  (func (export "unimplemented_2") (param (ref eq)) (param (ref eq)) (result (ref eq))
    (unreachable))

  (func (export "unimplemented_3") (param (ref eq)) (param (ref eq)) (param (ref eq)) (result (ref eq))
    (unreachable))

)

(register "runtime")