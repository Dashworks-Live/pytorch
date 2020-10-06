#include <ATen/Dispatch.h>
#include <ATen/native/ForeachUtils.h>
#include <ATen/native/cuda/ForeachFunctors.cuh>

namespace at { namespace native {

template<template<class> class Op>
std::vector<Tensor> foreach_pointwise_op(TensorList input, TensorList tensors1, TensorList tensors2, Scalar scalar) {
    std::vector<std::vector<at::Tensor>> tensor_lists;
    std::vector<at::Tensor> vec_res;
    vec_res.reserve(input.size());
    for (const auto& t: input) {
        vec_res.emplace_back(at::native::empty_like(t));
    }

    tensor_lists.emplace_back(input.vec());
    tensor_lists.emplace_back(tensors1.vec());
    tensor_lists.emplace_back(tensors2.vec());
    tensor_lists.emplace_back(std::move(vec_res));

    AT_DISPATCH_ALL_TYPES_AND(kHalf, input[0].scalar_type(), "foreach_pointwise_op_cuda", [&]() {
        using opmath_t = get_opmath_t<scalar_t>::opmath_t;
        multi_tensor_apply<4>(tensor_lists,
                              PointwiseOpFunctor<scalar_t>(),
                              Op<opmath_t>(),
                              scalar.to<opmath_t>());
    });

    return tensor_lists[3];
}

template<template<class> class Op>
void foreach_pointwise_op_(TensorList input, TensorList tensors1, TensorList tensors2, at::ArrayRef<double> scalars) {
    std::vector<std::vector<at::Tensor>> tensor_lists;
    tensor_lists.emplace_back(input.vec());
    tensor_lists.emplace_back(tensors1.vec());
    tensor_lists.emplace_back(tensors2.vec());

    AT_DISPATCH_ALL_TYPES_AND(kHalf, input[0].scalar_type(), "foreach_pointwise_op__cuda", [&]() {
        using opmath_t = get_opmath_t<scalar_t>::opmath_t;
        multi_tensor_apply<3>(tensor_lists,
                              scalars,
                              PointwiseOpScalarListFunctor_<scalar_t>(),
                              Op<opmath_t>());
    });
}

template<template<class> class Op>
std::vector<Tensor> foreach_pointwise_op(TensorList input, TensorList tensors1, TensorList tensors2, at::ArrayRef<double> scalars) {
    std::vector<std::vector<at::Tensor>> tensor_lists;
    std::vector<at::Tensor> vec_res;
    vec_res.reserve(input.size());
    for (const auto& t: input) {
        vec_res.emplace_back(at::native::empty_like(t));
    }

    tensor_lists.emplace_back(input.vec());
    tensor_lists.emplace_back(tensors1.vec());
    tensor_lists.emplace_back(tensors2.vec());
    tensor_lists.emplace_back(std::move(vec_res));

    AT_DISPATCH_ALL_TYPES_AND(kHalf, input[0].scalar_type(), "foreach_pointwise_op_cuda", [&]() {
        using opmath_t = get_opmath_t<scalar_t>::opmath_t;
        multi_tensor_apply<4>(tensor_lists,
                              scalars,
                              PointwiseOpScalarListFunctor<scalar_t>(),
                              Op<opmath_t>());
    });

    return tensor_lists[3];
}

template<template<class> class Op>
void foreach_pointwise_op_(TensorList input, TensorList tensors1, TensorList tensors2, Scalar scalar) {
    std::vector<std::vector<at::Tensor>> tensor_lists;
    tensor_lists.emplace_back(input.vec());
    tensor_lists.emplace_back(tensors1.vec());
    tensor_lists.emplace_back(tensors2.vec());

    AT_DISPATCH_ALL_TYPES_AND(kHalf, input[0].scalar_type(), "foreach_pointwise_op__cuda", [&]() {
        using opmath_t = get_opmath_t<scalar_t>::opmath_t;
        multi_tensor_apply<3>(tensor_lists,
                              PointwiseOpFunctor_<scalar_t>(),
                              Op<opmath_t>(),
                              scalar.to<opmath_t>());
    });
}

#define FOREACH_POINTWISE_OP_SCALAR(NAME, OP)                                                                                         \
std::vector<Tensor> foreach_tensor_##NAME##_scalar_cuda(TensorList input, TensorList tensors1, TensorList tensors2, Scalar scalar) {  \
    TORCH_CHECK(input.size() > 0, "Tensor list must have at least one tensor.");                                                      \
    TORCH_CHECK(input.size() ==  tensors1.size(), "Tensor lists must be of the same length.");                                        \
    TORCH_CHECK(tensors1.size() ==  tensors2.size(), "Tensor lists must be of the same length.");                                     \
                                                                                                                                      \
    if (!can_use_fast_route(input, scalar) ||                                                                                         \
        !can_use_fast_route(tensors1, tensors2) ||                                                                                    \
        !can_use_fast_route(input, tensors1)) {                                                                                       \
        return at::native::foreach_tensor_##NAME##_scalar_slow(input, tensors1, tensors2, scalar);                                    \
    }                                                                                                                                 \
                                                                                                                                      \
    return foreach_pointwise_op<OP>(input, tensors1, tensors2, scalar);                                                               \
}                                                                                                                                     \
                                                                                                                                      \
void foreach_tensor_##NAME##_scalar_cuda_(TensorList input, TensorList tensors1, TensorList tensors2, Scalar scalar) {                \
    TORCH_CHECK(input.size() > 0, "Tensor list must have at least one tensor.");                                                      \
    TORCH_CHECK(input.size() ==  tensors1.size(), "Tensor lists must be of the same length.");                                        \
    TORCH_CHECK(tensors1.size() ==  tensors2.size(), "Tensor lists must be of the same length.");                                     \
                                                                                                                                      \
    if (!can_use_fast_route(input, scalar) ||                                                                                         \
        !can_use_fast_route(tensors1, tensors2) ||                                                                                    \
        !can_use_fast_route(input, tensors1)) {                                                                                       \
        return at::native::foreach_tensor_##NAME##_scalar_slow_(input, tensors1, tensors2, scalar);                                   \
    }                                                                                                                                 \
                                                                                                                                      \
    foreach_pointwise_op_<OP>(input, tensors1, tensors2, scalar);                                                                     \
}


#define FOREACH_POINTWISE_OP_SCALARLIST(NAME, OP)                                                                                                        \
std::vector<Tensor> foreach_tensor_##NAME##_scalarlist_cuda(TensorList input, TensorList tensors1, TensorList tensors2, at::ArrayRef<double> scalars) {  \
    TORCH_CHECK(input.size() > 0, "Tensor list must have at least one tensor.");                                                                         \
    TORCH_CHECK(input.size() ==  tensors1.size(), "Tensor lists must be of the same length.");                                                           \
    TORCH_CHECK(tensors1.size() ==  tensors2.size(), "Tensor lists must be of the same length.");                                                        \
                                                                                                                                                         \
    if (!can_use_fast_route(tensors1, tensors2) ||                                                                                                       \
        !can_use_fast_route(input, tensors1)) {                                                                                                          \
        return at::native::foreach_tensor_##NAME##_scalarlist_slow(input, tensors1, tensors2, scalars);                                                  \
    }                                                                                                                                                    \
                                                                                                                                                         \
    return foreach_pointwise_op<OP>(input, tensors1, tensors2, scalars);                                                                                 \
}                                                                                                                                                        \
                                                                                                                                                         \
void foreach_tensor_##NAME##_scalarlist_cuda_(TensorList input, TensorList tensors1, TensorList tensors2, at::ArrayRef<double> scalars) {                \
    TORCH_CHECK(input.size() > 0, "Tensor list must have at least one tensor.");                                                                         \
    TORCH_CHECK(input.size() ==  tensors1.size(), "Tensor lists must be of the same length.");                                                           \
    TORCH_CHECK(tensors1.size() ==  tensors2.size(), "Tensor lists must be of the same length.");                                                        \
                                                                                                                                                         \
    if (!can_use_fast_route(tensors1, tensors2) ||                                                                                                       \
        !can_use_fast_route(input, tensors1)) {                                                                                                          \
        return at::native::foreach_tensor_##NAME##_scalarlist_slow_(input, tensors1, tensors2, scalars);                                                 \
    }                                                                                                                                                    \
                                                                                                                                                         \
    foreach_pointwise_op_<OP>(input, tensors1, tensors2, scalars);                                                                                       \
}

FOREACH_POINTWISE_OP_SCALAR(addcmul, std::multiplies);
FOREACH_POINTWISE_OP_SCALAR(addcdiv, std::divides);
FOREACH_POINTWISE_OP_SCALARLIST(addcmul, std::multiplies);
FOREACH_POINTWISE_OP_SCALARLIST(addcdiv, std::divides);

}} // namespace at::native
