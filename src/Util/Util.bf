using System;
using System.Collections;
using System.Reflection;

namespace Serialize.Util
{
	static class Util
	{
		public static bool IsPrimitive(Type type)
		{
			for (let i in type.Interfaces)
			{
				if (i == typeof(ISerializeAsPrimitive))
					return true;
			}

			if (type.IsEnum && type.IsUnion)
				return false;

			let generic = type as SpecializedGenericType;

			return type.IsPrimitive ||
				type.IsTypedPrimitive ||
				type.IsEnum ||
				type == typeof(String) ||
				type == typeof(DateTime) ||
				generic?.UnspecializedType == typeof(Nullable<>) &&
				IsPrimitive(generic.GetGenericArg(0));
		}

		public static bool IsPrimitive<T>() where T : ISerializable
		{
			return IsPrimitive(typeof(T));
		}

		public static bool IsPrimitive<TValue>(TValue object) where TValue : ISerializable
		{
			return IsPrimitive(object.__SerializeActualType);
		}

		public static bool IsList(Type type)
		{
			for (let i in type.Interfaces)
			{
				if (i == typeof(ISerializeAsList))
					return true;
			}

			return (type is SpecializedGenericType &&
				(type as SpecializedGenericType).UnspecializedType == typeof(List<>)) ||
				type.IsArray;
		}

		public static bool IsList<T>() where T : ISerializable
		{
			return IsList(typeof(T));
		}

		public static bool IsList<T>(T object) where T : ISerializable
		{
			return IsList(object.__SerializeActualType);
		}

		public static bool IsMap(Type type)
		{
			return !IsPrimitive(type) && !IsList(type);
		}

		public static bool IsMap<T>() where T : ISerializable
		{
			return IsMap(typeof(T));
		}

		public static bool IsMap<T>(T object) where T : ISerializable
		{
			return !IsPrimitive(object) && !IsList(object);
		}

		public static bool CanBeAny(Type type)
		{
			return type.IsEnum && type.IsUnion;
		}

		public static Type GetInnerType(Type type)
		{
			let generic = type as SpecializedGenericType;
			switch (generic?.UnspecializedType)
			{
			case typeof(List<>): return generic.GetGenericArg(0);
			case typeof(Dictionary<>): return generic.GetGenericArg(1);
			}

			if (IsMap(type))
				return typeof(Variant);

			return null;
		}
	}
}